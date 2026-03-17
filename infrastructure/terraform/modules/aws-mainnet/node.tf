resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "node_cloudwatch" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "node_runtime_access" {
  name = "${local.name_prefix}-node-runtime-access"
  role = aws_iam_role.node.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
        Resource = [
          aws_kms_key.platform.arn,
          aws_secretsmanager_secret.arc_credentials.arn,
          aws_secretsmanager_secret.protocol_keys.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.node.arn}:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node" {
  name = "${local.name_prefix}-node"
  role = aws_iam_role.node.name
}

resource "aws_launch_template" "node" {
  name_prefix   = "${local.name_prefix}-node-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.node_instance_type
  user_data = base64encode(templatefile("${path.module}/templates/node-bootstrap.sh.tftpl", {
    artifacts_bucket    = aws_s3_bucket.artifacts.id
    genesis_key         = aws_s3_object.genesis.key
    node_image          = local.node_image
    node_registry       = local.node_registry
    node_http_port      = var.node_http_port
    node_log_group_name = aws_cloudwatch_log_group.node.name
    aws_region          = var.aws_region
    arc_secret_arn      = aws_secretsmanager_secret.arc_credentials.arn
    protocol_network    = local.protocol_network
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
  }

  vpc_security_group_ids = [aws_security_group.node.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted   = true
      kms_key_id  = aws_kms_key.platform.arn
      volume_type = "gp3"
      volume_size = 50
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }
}

resource "aws_autoscaling_group" "node" {
  name                      = "${local.name_prefix}-node"
  min_size                  = var.node_min_size
  desired_capacity          = var.node_desired_capacity
  max_size                  = var.node_max_size
  vpc_zone_identifier       = values(aws_subnet.private)[*].id
  health_check_type         = "ELB"
  health_check_grace_period = 240
  target_group_arns         = [aws_lb_target_group.node.arn]

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 67
      instance_warmup        = 180
    }

    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-node"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
