#!/usr/bin/env bash
# Apply the unified schema to the RDS PostgreSQL instance after the first terraform apply.
# Run from within the VPC (e.g., a bastion, a Kubernetes Job, or an EC2 instance in the VPC).
#
# Prerequisites:
#   - psql installed
#   - TF_VAR_db_password set in the environment
#   - RDS endpoint reachable (must be inside the VPC)
#
# Usage:
#   RDS_ENDPOINT=$(cd environments/prod && terraform output -raw rds_endpoint)
#   TF_VAR_db_password=<password> ./scripts/run-migrations.sh <RDS_ENDPOINT>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/../modules/database/schema.sql"

RDS_ENDPOINT="${1:-}"

if [[ -z "${RDS_ENDPOINT}" ]]; then
  echo "Usage: $0 <rds-endpoint>"
  echo ""
  echo "Get the endpoint with:"
  echo "  cd environments/prod && terraform output -raw rds_endpoint"
  exit 1
fi

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  echo "Error: TF_VAR_db_password environment variable is not set"
  exit 1
fi

echo "=== Applying SecureStay schema to RDS ==="
echo "Endpoint : ${RDS_ENDPOINT}"
echo "Database : securestay"
echo "Schema   : ${SCHEMA_FILE}"
echo ""

PGPASSWORD="${TF_VAR_db_password}" psql \
  -h "${RDS_ENDPOINT}" \
  -U securestay_admin \
  -d securestay \
  -f "${SCHEMA_FILE}"

echo ""
echo "=== Schema applied. Seed data loaded. ==="
