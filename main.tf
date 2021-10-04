provider "aws" {
  region                  = var.region
  shared_credentials_file = "${path.module}/credentials"
}

terraform {
  backend "s3" {
    bucket   = "devops-terraform-backend-avm-2"
    key      = "ecsDemo/terraform.tfstate"
    region   = "us-east-1"
  }
}

//Cluster
resource "aws_ecs_cluster" "cluster" {
  name               = "${var.env}-Cluster"
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 40
    base              = 0
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 60
    base              = 1
  }

  tags = {
    env       = "${var.env}"
    terraform = "true"
  }
}

//Application 1
resource "aws_ecs_task_definition" "service" {
  family = "service-${var.env}"
  network_mode = "awsvpc"
  container_definitions = jsonencode([
    {
      name      = "service-${var.env}"
      image     = "public.ecr.aws/t0r2k2r7/demo"
      essential = true
      environment = [
        {"name": "MYSQL_HOST", "value": aws_db_instance.default.endpoint},
        {"name": "MYSQL_USER", "value": aws_db_instance.default.username},
        {"name": "MYSQL_PASSWORD", "value": aws_db_instance.default.password},
        {"name": "MYSQL_DB", "value": aws_db_instance.default.name}
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  cpu = 256
  memory = 512 

  tags = {
    env       = "${var.env}"
    terraform = "true"
  }
}

resource "aws_lb" "load_balancer" {
  name               = "loadbalance"
  internal           = false
  load_balancer_type = "application"
  subnets = [ "subnet-cf1277a9", "subnet-4c05b316" ]
  security_groups = [ "sg-4af9fb00" ]

    tags = {
    env = "${var.env}"
    terraform = true
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-6603a800"
  target_type = "ip"
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }
}

resource "aws_ecs_service" "service" {
  
  name            = "service-${var.env}"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type = "FARGATE"
  network_configuration {
      subnets = [ "subnet-cf1277a9", "subnet-4c05b316" ]
      security_groups = [ "sg-4af9fb00" ]
      assign_public_ip = true //False on prod
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "service-${var.env}"
    container_port   = 3000
  }
    tags = {
    env = "${var.env}"
    terraform = true
  }
  depends_on = [
    aws_lb_listener.listener,
  ]
}

output "alb_dns" {
  value = aws_lb.load_balancer.dns_name
}