terraform {
  backend "s3" {
    bucket       = "cloud-design-remote-state"
    key          = "infra/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
