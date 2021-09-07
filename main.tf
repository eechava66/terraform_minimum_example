provider "aws" {
  region                  = var.region
  shared_credentials_file = "${path.module}/credentials"
}

//Cluster
resource "aws_ecs_cluster" "cluster" {
  name               = "${var.env}-Cluster"
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 40
    base              = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 60
    base              = 0
  }

  tags = {
    env       = "${var.env}"
    terraform = "true"
  }
}

