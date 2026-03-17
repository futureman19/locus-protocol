resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_runtime_access" {
  name = "${local.name_prefix}-ecs-runtime-access"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
        Resource = [
          aws_kms_key.platform.arn,
          aws_secretsmanager_secret.indexer_runtime.arn,
          aws_secretsmanager_secret.indexer_db_connection.arn,
          aws_secretsmanager_secret.protocol_keys.arn
        ]
      }
    ]
  })
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_lb" "public" {
  name               = substr("${local.name_prefix}-public", 0, 32)
  load_balancer_type = "application"
  internal           = false
  subnets            = values(aws_subnet.public)[*].id
  security_groups    = [aws_security_group.public_alb.id]
  idle_timeout       = 60
  tags               = local.common_tags
}

resource "aws_lb" "internal" {
  name               = substr("${local.name_prefix}-internal", 0, 32)
  load_balancer_type = "application"
  internal           = true
  subnets            = values(aws_subnet.private)[*].id
  security_groups    = [aws_security_group.internal_alb.id]
  idle_timeout       = 60
  tags               = local.common_tags
}

resource "aws_lb_target_group" "indexer" {
  name        = substr("${local.name_prefix}-indexer", 0, 32)
  port        = var.indexer_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "ghost" {
  name        = substr("${local.name_prefix}-ghost", 0, 32)
  port        = var.ghost_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "node" {
  name        = substr("${local.name_prefix}-node", 0, 32)
  port        = var.node_http_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "public_http" {
  count             = local.tls_enabled ? 0 : 1
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.indexer.arn
  }
}

resource "aws_lb_listener" "public_http_redirect" {
  count             = local.tls_enabled ? 1 : 0
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "public_https" {
  count             = local.tls_enabled ? 1 : 0
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.indexer.arn
  }
}

resource "aws_lb_listener" "internal_ghost" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.ghost_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghost.arn
  }
}

resource "aws_lb_listener" "internal_node" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.node_http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node.arn
  }
}

resource "aws_route53_record" "public_indexer" {
  count   = var.route53_zone_id != "" && var.domain_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}

resource "aws_ecs_task_definition" "indexer" {
  family                   = "${local.name_prefix}-indexer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.indexer_cpu)
  memory                   = tostring(var.indexer_memory)
  execution_role_arn       = aws_iam_role.ecs_task.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "indexer"
      image     = local.indexer_image
      essential = true
      portMappings = [
        {
          containerPort = var.indexer_port
          hostPort      = var.indexer_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "HOST", value = "0.0.0.0" },
        { name = "PORT", value = tostring(var.indexer_port) },
        { name = "NETWORK", value = local.protocol_network },
        { name = "DATABASE_NAME", value = var.db_name },
        { name = "DATABASE_SSL", value = "true" },
        { name = "DATABASE_SSL_REJECT_UNAUTHORIZED", value = "true" },
        { name = "JUNGLEBUS_URL", value = var.junglebus_url },
        { name = "START_BLOCK", value = tostring(var.start_block) },
        { name = "LOG_LEVEL", value = var.log_level }
      ]
      secrets = [
        { name = "DATABASE_SECRET_JSON", valueFrom = aws_secretsmanager_secret.indexer_db_connection.arn },
        { name = "INDEXER_RUNTIME_SECRET_JSON", valueFrom = aws_secretsmanager_secret.indexer_runtime.arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.indexer.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "ghost" {
  family                   = "${local.name_prefix}-ghost"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.ghost_cpu)
  memory                   = tostring(var.ghost_memory)
  execution_role_arn       = aws_iam_role.ecs_task.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "ghost-runtime"
      image     = local.ghost_image
      essential = true
      portMappings = [
        {
          containerPort = var.ghost_port
          hostPort      = var.ghost_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "GHOST_RUNTIME_ADDR", value = "0.0.0.0:${var.ghost_port}" },
        { name = "LOG_LEVEL", value = var.log_level },
        { name = "RUST_LOG", value = var.log_level }
      ]
      secrets = [
        { name = "PROTOCOL_KEYS_SECRET_JSON", valueFrom = aws_secretsmanager_secret.protocol_keys.arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ghost.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "indexer" {
  name            = "${local.name_prefix}-indexer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.indexer.arn
  desired_count   = var.indexer_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.indexer.arn
    container_name   = "indexer"
    container_port   = var.indexer_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_execute_command             = true
  wait_for_steady_state              = false

  tags = local.common_tags
}

resource "aws_ecs_service" "ghost" {
  name            = "${local.name_prefix}-ghost"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ghost.arn
  desired_count   = var.ghost_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ghost.arn
    container_name   = "ghost-runtime"
    container_port   = var.ghost_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_execute_command             = true
  wait_for_steady_state              = false

  tags = local.common_tags
}

resource "aws_appautoscaling_target" "indexer" {
  max_capacity       = max(var.indexer_desired_count * 2, 2)
  min_capacity       = max(var.indexer_desired_count, 1)
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.indexer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "indexer_cpu" {
  name               = "${local.name_prefix}-indexer-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.indexer.resource_id
  scalable_dimension = aws_appautoscaling_target.indexer.scalable_dimension
  service_namespace  = aws_appautoscaling_target.indexer.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "ghost" {
  max_capacity       = max(var.ghost_desired_count * 2, 2)
  min_capacity       = max(var.ghost_desired_count, 1)
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.ghost.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ghost_cpu" {
  name               = "${local.name_prefix}-ghost-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ghost.resource_id
  scalable_dimension = aws_appautoscaling_target.ghost.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ghost.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
