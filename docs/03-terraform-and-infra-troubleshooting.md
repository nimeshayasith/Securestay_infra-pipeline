# Terraform And Infrastructure Troubleshooting

## 1. Purpose Of This Document

This document lists the main Terraform, AWS, EKS, Helm, and pipeline errors that appeared while bringing the SecureStay production environment back up.

The goal is to make future recovery easier. If the infrastructure is destroyed with `terraform destroy` and later recreated with `terraform apply`, this document explains the common errors, why they happen, and how to fix them safely.

## 2. Normal Production Commands

Use these commands from the production Terraform folder:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply -auto-approve -input=false
```

To destroy production infrastructure:

```bash
cd environments/prod
terraform init
terraform destroy -auto-approve -input=false
```

Important:

- Do not run `terraform apply` and `terraform destroy` at the same time.
- Do not run two `terraform apply` jobs at the same time.
- Keep the GitHub Actions `apply`, `plan`, and `destroy` workflows serialized so they do not fight over the same Terraform state.

## 3. Error: Missing AWS Region In GitHub Actions

### Concept

AWS resources live inside regions. A region is a physical AWS location such as `us-east-1`.

When GitHub Actions talks to AWS, it must know which region to use. Without the region, AWS commands do not know where to look for resources such as EKS clusters, RDS databases, ECR repositories, DynamoDB lock tables, or S3 state buckets.

### Why This Is Important

The same AWS account can have resources in many regions.

For example, an EKS cluster named `securestay-eks` in `us-east-1` is different from a cluster with the same name in another region. If the workflow does not know the region, it cannot safely connect to the correct infrastructure.

### Error Message

```text
Error: Input required and not supplied: aws-region
```

### Cause

The GitHub Actions step `aws-actions/configure-aws-credentials@v4` requires an AWS region.

The workflow expected `secrets.AWS_REGION`, but the secret was missing.

### Fix

Use a fallback region in workflow files:

```yaml
aws-region: ${{ secrets.AWS_REGION || vars.AWS_REGION || 'us-east-1' }}
```

This makes the workflow work even if the GitHub secret is not configured.

### Prevention

Keep one of these configured in GitHub:

- `AWS_REGION` secret
- `AWS_REGION` repository variable

For this project, the expected region is:

```text
us-east-1
```

## 4. Error: Terraform State Lock

### Concept

Terraform state is the file that records what Terraform created in AWS.

This project stores Terraform state remotely in S3. It also uses DynamoDB for state locking. A state lock means only one Terraform operation can modify or inspect the state at a time.

### Why This Is Important

Terraform state is very sensitive because Terraform uses it to decide what to create, update, or delete.

If two `terraform apply` commands run at the same time, both may try to update the same resources and state file. That can cause duplicated resources, broken infrastructure, or corrupted state.

The lock protects the production environment from accidental parallel changes.

### Error Message

```text
Error acquiring the state lock
ConditionalCheckFailedException: The conditional request failed
Operation: OperationTypePlan
Path: securestay-terraform-state-209998132740/prod/terraform.tfstate
```

### Cause

Terraform uses a DynamoDB lock table to prevent two Terraform commands from modifying the same state at the same time.

This error usually means one of these happened:

- A `terraform plan` is still running.
- A `terraform apply` is still running.
- A previous GitHub Actions run was cancelled and left a temporary lock.
- Two workflows started close together.

### Safe Fix

First check whether another Terraform run is active in GitHub Actions.

If no Terraform command is running, inspect the DynamoDB lock table:

```bash
aws dynamodb get-item \
  --region us-east-1 \
  --table-name securestay-terraform-locks \
  --key '{"LockID":{"S":"securestay-terraform-state-209998132740/prod/terraform.tfstate"}}'
```

If the lock is old and no Terraform run is active, unlock it:

```bash
cd environments/prod
terraform force-unlock <LOCK_ID>
```

Use the lock ID shown in the Terraform error.

### What Not To Do

Avoid this unless it is an emergency:

```bash
terraform apply -lock=false
```

Disabling the lock can corrupt Terraform state if another run is active.

### Prevention

Use GitHub Actions concurrency so plan/apply/destroy do not overlap:

```yaml
concurrency:
  group: terraform-prod
  cancel-in-progress: false
```

## 5. Error: NGINX Ingress Helm Install Timeout

### Concept

Ingress is the Kubernetes entry point for HTTP/HTTPS traffic.

The NGINX ingress controller receives external traffic from an AWS Load Balancer and routes it to services running inside the cluster.

Helm is used to install NGINX ingress into Kubernetes. Helm can wait for Kubernetes resources to become ready, but cloud resources such as AWS Load Balancers may take extra time to appear.

### Why This Is Important

Without ingress, users cannot reach the application from the internet.

Even if application pods are running, the system is not useful externally unless traffic can enter the cluster. That is why ingress health is a key part of the production deployment.

This error also matters because it can hide the real cause. A Helm timeout may be caused by node capacity, webhooks, service creation, or AWS load balancer provisioning.

### Error Message

```text
Error: failed pre-install: timed out waiting for the condition
```

or:

```text
Error: UPGRADE FAILED: pre-upgrade hooks failed: timed out waiting for the condition
```

or:

```text
Error: context deadline exceeded
```

### Cause

The NGINX ingress controller was not the real problem by itself.

The cluster was slow or unable to finish all related Kubernetes operations before Helm timed out. In this project, there were two main reasons:

- EKS worker nodes were too small and ran out of pod/IP capacity.
- A stale AWS Load Balancer Controller webhook existed without healthy endpoints.

### Fix Applied In The Pipeline

The workflow now installs NGINX ingress without relying only on `helm --wait`.

It does these steps separately:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.replicaCount=1 \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.service.type=LoadBalancer

kubectl rollout status deployment/ingress-nginx-controller \
  -n ingress-nginx \
  --timeout=15m
```

Then it waits for the service and load balancer hostname separately.

### Why This Is Better

Helm can fail too early while AWS is still creating or reconciling the load balancer.

Waiting with `kubectl` makes the pipeline easier to debug because each stage has its own logs.

## 6. Error: AWS Load Balancer Webhook Has No Endpoints

### Concept

Kubernetes admission webhooks are API checks that run when resources are created or updated.

The AWS Load Balancer Controller installs webhooks so it can inspect and modify Kubernetes objects related to AWS load balancers.

An endpoint is the actual pod behind a Kubernetes Service. If a webhook Service exists but has no endpoints, Kubernetes tries to call the webhook but there is no healthy pod to answer.

### Why This Is Important

Admission webhooks can block Kubernetes resource creation.

In this project, a stale AWS Load Balancer webhook blocked creation of the NGINX LoadBalancer Service. That means one broken leftover webhook could stop ingress from being installed.

This is especially important after failed installs, partial destroys, or repeated pipeline retries.

### Error Message

```text
Internal error occurred: failed calling webhook "mservice.elbv2.k8s.aws"
no endpoints available for service "aws-load-balancer-webhook-service"
```

### Cause

The AWS Load Balancer Controller webhook configuration still existed in the cluster, but the controller pod/service was not healthy.

This can happen after partial installs, failed Helm runs, or destroying/recreating infrastructure.

When this stale webhook exists, Kubernetes tries to call it during Service creation, including the NGINX LoadBalancer Service creation. Because the webhook has no endpoints, the request fails.

### Fix

Delete the stale AWS Load Balancer Controller objects:

```bash
kubectl delete deployment aws-load-balancer-controller \
  -n kube-system \
  --ignore-not-found=true

kubectl delete service aws-load-balancer-webhook-service \
  -n kube-system \
  --ignore-not-found=true

kubectl delete secret aws-load-balancer-tls \
  -n kube-system \
  --ignore-not-found=true

kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook \
  --ignore-not-found=true

kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook \
  --ignore-not-found=true
```

### Pipeline Behavior

The infra apply workflow now checks whether the required service account exists:

```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
```

If the service account is missing, the workflow skips installing the AWS Load Balancer Controller and cleans stale webhook resources.

## 7. Error: EKS Pod IP Exhaustion

### Concept

In AWS EKS, pods receive IP addresses from the VPC through the AWS VPC CNI plugin.

Each worker node can support only a limited number of pod IP addresses. Smaller EC2 instances support fewer pods.

This project used `t3.micro` nodes, which are very small. They are useful for cost control, but they have limited pod capacity.

### Why This Is Important

Kubernetes scheduling is not only about CPU and memory. In EKS, pod IP capacity is also a hard limit.

If the cluster runs out of pod IPs, new pods cannot start even if the node still appears to have some CPU or memory available.

This can break core services such as ingress, RabbitMQ, and application deployments.

### Error Message

```text
FailedCreatePodSandBox
plugin type="aws-cni" name="aws-cni" failed (add):
failed to assign an IP address to container
```

### Cause

The EKS worker nodes were `t3.micro`.

Small EC2 instance types have very limited pod/IP capacity. The cluster had only enough capacity for a few system pods and not enough room for all application pods, RabbitMQ, and ingress.

### Fix Applied

The EKS node group was scaled from 2 nodes to 3 nodes:

```hcl
scaling_config {
  desired_size = 3
  min_size     = 3
  max_size     = 3
}
```

The VPC CNI add-on also enables prefix delegation:

```hcl
configuration_values = jsonencode({
  env = {
    ENABLE_PREFIX_DELEGATION = "true"
    WARM_PREFIX_TARGET       = "1"
  }
})
```

### Verification

Check node readiness:

```bash
kubectl get nodes -o wide
```

Check pod failures:

```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
```

### Long-Term Recommendation

For a student/free-tier style environment, 3 `t3.micro` nodes can work, but capacity is still tight.

For a more stable production-like environment, use larger nodes such as:

```text
t3.small
t3.medium
```

## 8. Error: NGINX Ingress Service Disappears During Retry

### Concept

A Kubernetes Service of type `LoadBalancer` asks the cloud provider to create an external load balancer.

For NGINX ingress, the important Service is:

```text
ingress-nginx-controller
```

When this Service is created, AWS creates a load balancer. When the Service is deleted, AWS deletes the load balancer.

### Why This Is Important

Load balancer creation and deletion are not instant.

If the pipeline repeatedly uninstalls and reinstalls ingress, Kubernetes and AWS can be busy deleting the old load balancer while the new install is trying to create another one. This creates unstable behavior and confusing logs.

For stable production pipelines, retries should be careful and should not delete healthy resources unnecessarily.

### Symptom

The controller pod is running:

```text
ingress-nginx-controller   1/1 Running
```

But the service is missing:

```text
Error from server (NotFound): services "ingress-nginx-controller" not found
```

Events show:

```text
EnsuredLoadBalancer
DeletingLoadBalancer
DeletedLoadBalancer
```

### Cause

The workflow was uninstalling and reinstalling `ingress-nginx` on every run.

That caused the LoadBalancer Service to be deleted while AWS was still reconciling the previous load balancer.

### Fix Applied

The workflow now only uninstalls `ingress-nginx` if the Helm release is already failed:

```bash
if helm status ingress-nginx -n ingress-nginx >/tmp/ingress-status.txt 2>/dev/null; then
  if grep -q '^STATUS: failed' /tmp/ingress-status.txt; then
    helm uninstall ingress-nginx -n ingress-nginx || true
  fi
fi
```

It no longer deletes the running ingress controller pod during normal retries.

## 9. Error: RabbitMQ Image Pull Or Chart Issues

### Concept

RabbitMQ is the message broker used by the SecureStay services.

It is installed into EKS by Terraform through a Helm chart. A Helm chart is a package of Kubernetes resources.

The RabbitMQ container image must also be pulled from a container registry before the pod can start.

### Why This Is Important

Messaging is part of the application platform. If RabbitMQ is not running, services that publish or consume events may fail.

Chart repositories and container registries are external dependencies. Even when Terraform code is correct, the deployment can fail if the chart source or image pull is unavailable, rate limited, or misconfigured.

### Possible Symptoms

```text
ImagePullBackOff
```

or Terraform/Helm chart download problems.

### Cause

RabbitMQ is installed through Terraform using the Bitnami Helm chart.

Older chart repository settings can fail or become unreliable. Also, Docker Hub image pulls can occasionally be rate limited or delayed.

### Fix Applied

The RabbitMQ Helm repository was changed to the OCI registry:

```hcl
repository = "oci://registry-1.docker.io/bitnamicharts"
```

RabbitMQ was also configured with small resource requests and no persistence for the lightweight environment:

```hcl
rabbitmq_persistence_enabled = false
rabbitmq_requests_cpu        = "50m"
rabbitmq_requests_memory     = "128Mi"
rabbitmq_limits_cpu          = "250m"
rabbitmq_limits_memory       = "256Mi"
```

### Verification

```bash
kubectl get pods -n messaging
kubectl describe pod -n messaging rabbitmq-0
kubectl logs -n messaging rabbitmq-0
```

## 10. Error: Application Migration Job Fails Against RDS

### Concept

The application uses a Kubernetes Job called `securestay-db-migrate` to prepare the PostgreSQL database schema.

This Job runs before the application Helm release finishes installing. It connects to the RDS PostgreSQL database using the Kubernetes secret:

```text
securestay-secrets.database-url
```

The `DATABASE_URL` must be valid for both the application and the `psql` command-line client.

### Why This Is Important

The database schema must exist before the application services can work correctly.

If the migration Job fails, Helm treats the application install as failed. That protects the application from starting with a missing or broken database schema.

This error is not a Terraform error directly, because Terraform already created RDS. However, it depends on Terraform-created infrastructure, so it is part of the full production recovery process.

### Error Message

```text
job securestay-db-migrate failed: BackoffLimitExceeded
```

Pod logs showed:

```text
psql: error: invalid sslmode value: "no-verify"
```

### Cause

The Kubernetes secret `securestay-secrets.database-url` used:

```text
sslmode=no-verify
```

The `psql` client does not support `no-verify` as a PostgreSQL `sslmode` value.

There was also a trailing newline in the secret value.

### Fix

Use:

```text
sslmode=require
```

The expected format is:

```text
postgresql://securestay_admin:<PASSWORD>@securestay-postgres.cobyyyqwodp4.us-east-1.rds.amazonaws.com:5432/securestay?sslmode=require
```

### Live Cluster Fix

Patch or recreate the Kubernetes secret so `database-url` has no trailing newline and uses `sslmode=require`.

Then delete the failed migration job so Helm can recreate it:

```bash
kubectl delete job securestay-db-migrate \
  -n securestay \
  --ignore-not-found=true
```

### Verification

Run a temporary PostgreSQL client pod/job from inside EKS and confirm it can connect:

```bash
kubectl run db-check \
  -n securestay \
  --rm -it \
  --image=postgres:15-alpine \
  --restart=Never \
  --env="DATABASE_URL=<DATABASE_URL>" \
  -- psql "$DATABASE_URL" -c "select current_database(), current_user;"
```

## 11. Error: Terraform Apply Succeeds But App Deploy Fails

### Concept

Infrastructure deployment and application deployment are connected but not the same thing.

Terraform creates the platform:

- VPC
- IAM
- EKS
- RDS
- ECR
- S3
- RabbitMQ
- ingress dependencies

The application pipeline deploys the software onto that platform using Kubernetes and Helm.

### Why This Is Important

A successful `terraform apply` means AWS infrastructure was created, but it does not guarantee the application is healthy.

The app still needs correct secrets, images, Helm values, database migrations, and enough cluster capacity.

Separating infrastructure failures from application failures makes debugging faster and safer.

### Cause

Terraform creates the AWS infrastructure, but the application deploy still depends on Kubernetes secrets and Helm values.

Terraform can be healthy while the app pipeline fails because of:

- wrong `DATABASE_URL`
- wrong `RABBITMQ_URL`
- missing image tag
- missing ECR image
- not enough EKS pod capacity
- failed Helm hook job

### Fix Strategy

Separate the troubleshooting:

```text
Terraform failure -> check environments/prod and AWS resources
EKS add-on failure -> check kube-system, ingress-nginx, messaging namespaces
Application failure -> check securestay namespace and app Helm chart
```

Useful commands:

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe job securestay-db-migrate -n securestay
kubectl logs job/securestay-db-migrate -n securestay --all-containers=true
```

## 12. Safe Recovery Order After `terraform destroy`

When everything has been destroyed and needs to be recreated, use this order:

1. Confirm backend exists.

```bash
cd bootstrap
terraform init
terraform apply
```

2. Apply production infrastructure.

```bash
cd ../environments/prod
terraform init
terraform apply -auto-approve -input=false
```

3. Update kubeconfig.

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name securestay-eks
```

4. Check EKS system health.

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

5. Check RabbitMQ.

```bash
kubectl get pods -n messaging
```

6. Install or verify ingress.

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

7. Deploy the application.

Run the application pipeline after the infrastructure pipeline is healthy.

## 13. Quick Checklist

Before rerunning a failed pipeline, check these:

- Is another Terraform workflow running?
- Is the Terraform lock still active?
- Is `AWS_REGION` set or using fallback `us-east-1`?
- Are all EKS nodes `Ready`?
- Are `coredns`, `aws-node`, and `kube-proxy` healthy?
- Are stale AWS Load Balancer webhooks removed?
- Is `ingress-nginx-controller` running?
- Does `ingress-nginx-controller` Service have a LoadBalancer endpoint?
- Is RabbitMQ running in the `messaging` namespace?
- Does `DATABASE_URL` use `sslmode=require`?
- Does `DATABASE_URL` have no trailing newline?

## 14. Most Important Rule

Do not immediately rerun the whole pipeline without checking the failed object first.

For Terraform errors, check Terraform state and locks.

For Helm errors, check the Kubernetes Job, pod logs, and namespace events.

For EKS errors, check node capacity and CNI events.

This saves time and avoids creating more partial resources.
