#!/usr/bin/env bash
# Run ONCE manually as nimesh-admin to create S3 state bucket + DynamoDB lock table.
# After this completes, update environments/prod/backend.tf with the printed account ID.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../bootstrap"

echo "=== SecureStay Bootstrap ==="
echo "Creating Terraform remote state backend (S3 + DynamoDB)..."
echo ""

cd "${BOOTSTRAP_DIR}"

terraform init
terraform apply -auto-approve

echo ""
echo "=== Bootstrap complete ==="
echo "Copy the account_id output above into environments/prod/backend.tf:"
echo "  bucket = \"securestay-terraform-state-<ACCOUNT_ID>\""
echo ""
echo "Then run: cd environments/prod && terraform init"
