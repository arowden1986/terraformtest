
terraform {
	backend "s3" {
		bucket = "ams-13536"
		key    = "terraform-state/git_workspace/terraform/environments/foundation/generated/testuser15/testdataplane/testdb"
		region = "us-east01"
	}
	required_providers {
		aws = "4.36.1"
	}
}
