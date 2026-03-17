resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = aws_kms_key.platform.arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.indexer.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  alarm_name          = "${local.name_prefix}-rds-replica-lag"
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 30
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.indexer_replica.id
  }
}

resource "aws_cloudwatch_metric_alarm" "indexer_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-indexer-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.public.arn_suffix
    TargetGroup  = aws_lb_target_group.indexer.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "ghost_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-ghost-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
    TargetGroup  = aws_lb_target_group.ghost.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "node_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-node-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
    TargetGroup  = aws_lb_target_group.node.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "indexer_service_cpu" {
  alarm_name          = "${local.name_prefix}-indexer-service-cpu"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.indexer.name
  }
}
