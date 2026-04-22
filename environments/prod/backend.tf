terraform {
  backend "s3" {
    # Replace <YOUR-ACCOUNT-ID> with the value printed by: cd bootstrap && terraform output account_id
    bucket         = "securestay-terraform-state-209998132740"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "securestay-terraform-locks"
    encrypt        = true
  }
}
