# SecureStay Demo Video Plan

## 1. Purpose Of This Document

This document is the plan for the SecureStay group demo video.

The demo should be around 20 minutes and should clearly show how the project moved from local microservice development to cloud deployment on AWS with automated pipelines.

There are four presenters:

- Kaweesha: project introduction and overall flow
- Lasindu: local application, Docker, and Minikube demo
- Nimesh: Terraform and AWS cloud infrastructure demo
- Diani: infrastructure pipeline and application pipeline demo

## 2. Recommended 20 Minute Timing

| Time | Presenter | Section |
| --- | --- | --- |
| 0:00 - 3:00 | Kaweesha | Project introduction and full system overview |
| 3:00 - 8:00 | Lasindu | Microservices, Docker, and local Minikube deployment |
| 8:00 - 14:00 | Nimesh | Terraform, AWS infrastructure, EKS, RDS, RabbitMQ, ingress |
| 14:00 - 19:00 | Diani | GitHub Actions infrastructure and application pipelines |
| 19:00 - 20:00 | All or Kaweesha | Final summary, lessons learned, and conclusion |

## 3. Demo Storyline

The demo should follow this story:

```text
Problem
  |
  v
SecureStay hotel booking web application
  |
  v
Microservices developed locally
  |
  v
Containerized with Docker
  |
  v
Tested locally with Docker Desktop and Minikube
  |
  v
Cloud infrastructure created with Terraform on AWS
  |
  v
Application deployed to EKS with Helm
  |
  v
Infrastructure and application deployment automated with GitHub Actions
```

The main message is:

```text
We built a microservice-based hotel booking system and moved it from local development to automated AWS cloud deployment.
```

## 4. Presenter 1: Kaweesha

### Section Goal

Kaweesha should explain the overall project in simple language before the technical demo starts.

This part should help the viewer understand what SecureStay is, why the architecture was chosen, and how the rest of the demo is organized.

### Suggested Time

3 minutes.

### What To Present

Start with the SecureStay idea:

```text
SecureStay is a hotel booking platform built using microservices. Users can view hotels and rooms, authenticate, make bookings, process payments, and trigger notifications.
```

Then explain the three main areas of the project:

| Area | Explanation |
| --- | --- |
| Local development on Windows | Developers built and tested services locally using Docker Desktop, Docker Compose, and Minikube. |
| Cloud development with AWS | Terraform created AWS infrastructure such as VPC, subnets, EKS, RDS, ECR, S3, IAM, NAT Gateway, and load balancers. |
| Automation with pipelines | GitHub Actions automated Terraform infrastructure deployment and application build/deploy workflows. |

### Key Points

- The system is split into microservices instead of one large application.
- Docker makes each service portable.
- Kubernetes helps run the services consistently.
- Terraform creates repeatable cloud infrastructure.
- GitHub Actions reduces manual deployment work.
- The project has two main pipeline areas: infrastructure pipeline and application pipeline.

### Suggested Speaking Script

```text
In this project, we built SecureStay, a simple hotel booking web application using a microservice architecture. The main goal was not only to build the application, but also to show how a real cloud-native system is developed, containerized, deployed, and automated.

We divided the project into three major parts. First, we developed and tested the services locally on Windows using Docker Desktop and Minikube. Second, we created production-like cloud infrastructure on AWS using Terraform. Third, we automated the deployment process using GitHub Actions pipelines.

The demo will follow the same journey. Lasindu will show the local microservice application and local Kubernetes setup. Nimesh will explain the AWS infrastructure and Terraform. Diani will explain how the infrastructure and application pipelines automate the deployment.
```

### Visuals To Show

- Overall architecture diagram
- List of microservices
- Short roadmap of local to cloud to automation
- GitHub repositories if available

## 5. Presenter 2: Lasindu

### Section Goal

Lasindu should show how the SecureStay application was developed locally before moving to AWS.

This section should prove that the application works as microservices and that it can run using containers.

### Suggested Time

5 minutes.

### What To Present

Explain the application services:

| Component | Responsibility |
| --- | --- |
| Frontend | User interface for SecureStay |
| API Gateway | Single entry point from frontend to backend services |
| Auth Service | Handles user login and user data |
| Booking Service | Handles hotels, rooms, and bookings |
| Payment Service | Handles payment records |
| Notification Service | Handles notification events |
| PostgreSQL | Local database for service data |
| RabbitMQ | Local message broker for async communication |

### Local Demo Flow

1. Show the project folders.

```powershell
cd "..\Project"
Get-ChildItem
Get-ChildItem services
```

2. Show Docker Compose services.

```powershell
docker compose ps
```

3. Start local services if needed.

```powershell
docker compose up --build -d
```

4. Show logs for one service.

```powershell
docker compose logs --tail 50 auth-service
docker compose logs --tail 50 booking-service
```

5. Open the frontend in browser.

```text
http://localhost:3001
```

6. Demonstrate user flow.

```text
Open frontend -> register or login -> view hotels/rooms -> make a booking -> show payment/notification flow if available
```

7. Show local database data.

If using local PostgreSQL from Docker Compose:

```powershell
docker compose exec postgres psql -U securestay -d securestay -c "select id, email, role, created_at from users order by created_at desc limit 5;"
docker compose exec postgres psql -U securestay -d securestay -c "select id, user_id, room_id, status, total_amount, created_at from bookings order by created_at desc limit 5;"
docker compose exec postgres psql -U securestay -d securestay -c "select id, booking_id, amount, status, created_at from payments order by created_at desc limit 5;"
```

8. Show RabbitMQ locally if needed.

```text
http://localhost:15672
```

Use the local RabbitMQ credentials configured for the local environment.

### Minikube Demo Flow

1. Show Minikube cluster.

```powershell
minikube status
kubectl get nodes
```

2. Show Kubernetes resources.

```powershell
kubectl get pods
kubectl get svc
kubectl get deployments
```

3. Apply local Kubernetes manifests if needed.

```powershell
kubectl apply -f k8s/
```

4. Port-forward the frontend or gateway.

```powershell
kubectl port-forward service/frontend 3001:80
```

or:

```powershell
minikube service frontend
```

### Key Points

- Docker Compose helped test all services together locally.
- Each microservice has its own container.
- Minikube gave a local Kubernetes environment before using AWS EKS.
- Local testing reduced cloud debugging time.
- The local environment is cheaper and faster for development.

### Suggested Speaking Script

```text
Before deploying to AWS, we first built and tested SecureStay locally. The application is split into frontend, gateway, auth, booking, payment, and notification services. Each service has its own Docker image, so it can run independently.

Docker Compose helped us run the full system locally, including PostgreSQL and RabbitMQ. After that, we tested Kubernetes deployment using Minikube. This gave us a local version of the cloud environment before moving to EKS.
```

## 6. Presenter 3: Nimesh

### Section Goal

Nimesh should explain how the production AWS infrastructure was created using Terraform and why cloud infrastructure is useful compared with only local deployment.

This part should connect the local application to the real cloud platform.

### Suggested Time

6 minutes.

### What To Present

Explain Terraform first:

```text
Terraform is Infrastructure as Code. Instead of manually creating AWS resources in the console, we write code that describes the infrastructure. Terraform then creates, updates, and destroys those resources in a repeatable way.
```

Then explain the module structure:

| Module | Purpose |
| --- | --- |
| `network` | Creates VPC, public subnets, private subnets, route tables, internet gateway, NAT gateways |
| `iam` | Creates IAM roles and permissions for EKS and users |
| `ecr` | Creates container repositories for Docker images |
| `storage` | Creates S3 buckets |
| `compute` | Creates EKS cluster and worker nodes |
| `database` | Creates RDS PostgreSQL |
| `rabbitmq` | Installs RabbitMQ into EKS using Helm |
| `dns` | Creates Route 53 DNS records when configured |

### Terraform Demo Commands

Run from the infrastructure repository:

```powershell
cd "c:\Users\nimes\OneDrive\Documents\7 th semester\EC7204 Cloud computing\Securestay_infra-pipeline"
cd environments\prod
terraform init
terraform validate
terraform plan
```

If showing already-created outputs:

```powershell
terraform output -raw rds_endpoint
terraform output ecr_repository_urls
terraform output database_url_format
```

Do not show real passwords.

### AWS And EKS Demo Commands

Update kubeconfig:

```powershell
aws eks update-kubeconfig --region us-east-1 --name securestay-eks
```

Show EKS cluster nodes:

```powershell
kubectl get nodes -o wide
```

Show system add-ons:

```powershell
kubectl get pods -n kube-system
```

Show RabbitMQ:

```powershell
kubectl get pods -n messaging
kubectl get svc -n messaging
```

Show ingress:

```powershell
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

Show application namespace:

```powershell
kubectl get pods -n securestay
kubectl get svc -n securestay
kubectl get ingress -n securestay
```

### Cloud Database Demo

Show that the application is using AWS RDS PostgreSQL.

Use a temporary Kubernetes Job or pod so the password stays inside the Kubernetes secret.

```powershell
@'
apiVersion: batch/v1
kind: Job
metadata:
  name: securestay-db-demo
  namespace: securestay
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: psql
          image: postgres:15-alpine
          command:
            - sh
            - -c
            - |
              psql "$DATABASE_URL" -c "select current_database(), current_user;"
              psql "$DATABASE_URL" -c "select id, email, role, created_at from users order by created_at desc limit 5;"
              psql "$DATABASE_URL" -c "select id, status, total_amount, created_at from bookings order by created_at desc limit 5;"
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: securestay-secrets
                  key: database-url
'@ | kubectl apply -f -

kubectl wait --for=condition=complete job/securestay-db-demo -n securestay --timeout=120s
kubectl logs job/securestay-db-demo -n securestay
kubectl delete job securestay-db-demo -n securestay --ignore-not-found=true
```

### Compare Local And Cloud

| Area | Local Platform | AWS Cloud Platform |
| --- | --- | --- |
| Cost | Usually free or very low | Can cost money because resources run in AWS |
| Speed | Fast for development | Slower to provision but closer to production |
| Reliability | Depends on developer machine | More reliable with managed AWS services |
| Scalability | Limited by laptop resources | Can scale using AWS infrastructure |
| Networking | Simple local ports | VPC, subnets, NAT, load balancers, security groups |
| Database | Local container database | Managed RDS PostgreSQL |
| Kubernetes | Minikube | Managed EKS |
| Automation | Mostly manual local commands | GitHub Actions and Terraform automation |

### Advantages Of AWS

- Production-like environment
- Managed database with RDS
- Managed Kubernetes control plane with EKS
- Central image registry with ECR
- Better security boundaries with IAM and security groups
- Load balancing and public access through AWS services
- Repeatable infrastructure through Terraform

### Disadvantages Of AWS

- More complex than local development
- Costs money if resources are left running
- Debugging can involve many services
- Provisioning takes more time
- Requires careful secret and permission management

### Key Points

- Terraform makes infrastructure repeatable.
- Remote state in S3 and locking in DynamoDB protect the infrastructure state.
- EKS runs the containers in the cloud.
- RDS stores production data.
- ECR stores Docker images built by the app pipeline.
- RabbitMQ supports event-based communication.
- Ingress and load balancers expose the application to users.

### Suggested Speaking Script

```text
After the local setup worked, we moved the system to AWS. I used Terraform to create the infrastructure as code. The infrastructure is split into modules, so networking, IAM, EKS, RDS, ECR, storage, RabbitMQ, and DNS are easier to manage.

The biggest advantage of Terraform is repeatability. If we destroy the environment, we can create it again using terraform apply. This is better than manually creating resources in the AWS Console.

Compared with the local setup, AWS is more powerful and production-like, but it is also more complex and can cost money. That is why automation and troubleshooting documentation are important.
```

## 7. Presenter 4: Diani

### Section Goal

Diani should explain how GitHub Actions automates both infrastructure and application deployment.

This section should show that the team does not need to manually build images, push images, create infrastructure, and deploy Helm charts every time.

### Suggested Time

5 minutes.

### What To Present

Explain the two pipeline areas:

| Pipeline | Repository | Main Purpose |
| --- | --- | --- |
| Infrastructure pipeline | `Securestay_infra-pipeline` | Creates, updates, plans, and destroys AWS infrastructure using Terraform |
| Application pipeline | `Project` | Builds Docker images, pushes to ECR, and deploys app services to EKS using Helm |

### Infrastructure Pipeline

Important workflow files:

```text
.github/workflows/infra-plan.yml
.github/workflows/infra-apply.yml
.github/workflows/infra-destroy.yml
```

What to show:

- `infra-plan.yml` runs Terraform formatting, validation, and plan.
- `infra-apply.yml` runs Terraform apply and installs/validates cluster components.
- `infra-destroy.yml` safely destroys infrastructure when manually confirmed.
- GitHub secrets provide AWS credentials and Terraform variables.
- Concurrency prevents unsafe overlapping Terraform runs.

Useful commands from the local repo:

```powershell
Get-Content .github\workflows\infra-plan.yml
Get-Content .github\workflows\infra-apply.yml
Get-Content .github\workflows\infra-destroy.yml
```

Useful GitHub UI demo:

```text
Open GitHub -> Actions -> Infrastructure Plan
Open GitHub -> Actions -> Infrastructure Apply
Open one successful run -> show Terraform init, validate, plan/apply, kubeconfig, ingress, outputs
```

### Application Pipeline

Important workflow file in the app repository:

```text
.github/workflows/app-pipeline.yml
```

What it does:

```text
Generate image tag
  |
  v
Build Docker images for frontend and backend services
  |
  v
Push images to AWS ECR
  |
  v
Create Kubernetes secrets
  |
  v
Run preflight checks
  |
  v
Helm upgrade/install into EKS
  |
  v
Verify rollouts and show public endpoint
```

Services built by the app pipeline:

- `frontend`
- `api-gateway`
- `auth-service`
- `booking-service`
- `payment-service`
- `notification-service`

Useful GitHub UI demo:

```text
Open GitHub -> Actions -> App Pipeline
Open one successful run
Show matrix build jobs
Show ECR push step
Show Helm deploy step
Show rollout verification
```

### ECR Verification Commands

```powershell
aws ecr describe-repositories --region us-east-1
aws ecr describe-images --repository-name securestay/frontend --region us-east-1 --query "imageDetails[0].imageTags"
aws ecr describe-images --repository-name securestay/auth-service --region us-east-1 --query "imageDetails[0].imageTags"
```

### Helm And Kubernetes Verification Commands

```powershell
helm list -n securestay
kubectl get pods -n securestay
kubectl get svc -n securestay
kubectl rollout status deployment/frontend -n securestay
kubectl rollout status deployment/api-gateway -n securestay
kubectl rollout status deployment/auth-service -n securestay
```

If `helm` is not installed locally, use Kubernetes commands and GitHub Actions logs instead.

### Key Points

- The infrastructure pipeline prepares the cloud platform.
- The application pipeline deploys the actual SecureStay services.
- ECR connects the app pipeline to EKS because EKS pulls images from ECR.
- Helm gives one repeatable deployment command for all app services.
- GitHub Actions keeps the deployment process consistent.
- Pipeline diagnostics make troubleshooting easier.

### Suggested Speaking Script

```text
The final part of the project is automation. We created two pipeline areas. The infrastructure pipeline manages AWS resources using Terraform. The application pipeline builds Docker images, pushes them to ECR, and deploys the application to EKS using Helm.

This means the team does not need to manually build and deploy each service. A code change can trigger the app pipeline, and infrastructure changes can be reviewed through Terraform plan before apply.
```

## 8. Full End-To-End Demo Scenario

Use this flow if the group wants one connected demo story.

### Step 1: Open Application

Open the local or cloud frontend.

Local:

```text
http://localhost:3001
```

Cloud:

```powershell
kubectl get svc frontend -n securestay -o wide
```

Use the external hostname or load balancer address shown by Kubernetes.

### Step 2: Login Or Register

Presenter action:

```text
Create a new user or login with an existing demo user.
```

### Step 3: Show User Data In Database

Local Docker database:

```powershell
docker compose exec postgres psql -U securestay -d securestay -c "select id, email, role, created_at from users order by created_at desc limit 5;"
```

Cloud RDS through Kubernetes secret:

```powershell
@'
apiVersion: batch/v1
kind: Job
metadata:
  name: securestay-users-demo
  namespace: securestay
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: psql
          image: postgres:15-alpine
          command:
            - sh
            - -c
            - psql "$DATABASE_URL" -c "select id, email, role, created_at from users order by created_at desc limit 5;"
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: securestay-secrets
                  key: database-url
'@ | kubectl apply -f -

kubectl wait --for=condition=complete job/securestay-users-demo -n securestay --timeout=120s
kubectl logs job/securestay-users-demo -n securestay
kubectl delete job securestay-users-demo -n securestay --ignore-not-found=true
```

### Step 4: Create Booking

Presenter action:

```text
Select hotel -> select room -> choose dates -> create booking.
```

Show booking data:

```powershell
docker compose exec postgres psql -U securestay -d securestay -c "select id, user_id, room_id, status, total_amount, created_at from bookings order by created_at desc limit 5;"
```

For cloud, use the same temporary Job pattern and change the SQL query:

```sql
select id, user_id, room_id, status, total_amount, created_at from bookings order by created_at desc limit 5;
```

### Step 5: Show Running Microservices

Local:

```powershell
docker compose ps
```

Cloud:

```powershell
kubectl get pods -n securestay
kubectl get svc -n securestay
```

### Step 6: Show Pipeline Evidence

Show GitHub Actions:

```text
Infrastructure Apply -> successful Terraform apply
App Pipeline -> successful image build and Helm deploy
```

## 9. Important Things To Avoid During Recording

- Do not show real AWS secret access keys.
- Do not show real database password values.
- Do not run `terraform destroy` during the demo unless this is specifically required.
- Do not run destructive Kubernetes commands unless they are part of a planned recovery demo.
- Do not wait for long cloud creation tasks during the recording. Use completed GitHub Actions logs where possible.
- Prepare browser tabs before recording to save time.

## 10. Final Conclusion

End the video with these points:

- The team created a microservice-based hotel booking system.
- The application was tested locally using Docker and Minikube.
- AWS infrastructure was created using Terraform.
- EKS, RDS, ECR, RabbitMQ, ingress, and networking were used for cloud deployment.
- GitHub Actions automated both infrastructure and application deployment.
- The project demonstrates a full DevOps lifecycle from development to cloud automation.
