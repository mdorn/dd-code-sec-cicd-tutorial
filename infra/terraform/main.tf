# Creating an ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Creating an ECS task definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.prefix}-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE", "EC2"]
  cpu                      = 512
  memory                   = 2048

  container_definitions = jsonencode([
    {
      name: "hello-world",
      image: "crccheck/hello-world",
      cpu: 512,
      memory: 2048,
      essential: true,
      portMappings: [
        {
          containerPort: 8000,
          hostPort: 8000,
        },
      ],
    },
  ])
}

# Creating an ECS service
resource "aws_ecs_service" "service" {
  name             = "${var.prefix}-service"
  cluster          = aws_ecs_cluster.cluster.id
  task_definition  = aws_ecs_task_definition.task.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = [aws_subnet.public_subnet.id]
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ECR repo
resource "aws_ecr_repository" "ecr_repo" {
  name                 = "${var.prefix}-repo/${var.app_image}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
