terraform {
  backend "s3" {
    bucket         = "terraform-state-us-east-1-782620204909"
    dynamodb_table = "terraform-state-locks"
    region         = "us-east-1"
    key            = "terraform.tfstate"
    encrypt        = true
    profile        = "satlabs"
  }
  required_version = "~> 1.9.3"
}
