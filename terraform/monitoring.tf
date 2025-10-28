# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "predictive_scaling" {
  name              = "/aws/lambda/${var.project_name}-predictive-scaling"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-predictive-scaling-logs"
  }
}

# SNS Topic for Scaling Notifications
resource "aws_sns_topic" "scaling_events" {
  name = "${var.project_name}-scaling-events"

  tags = {
    Name = "${var.project_name}-scaling-events"
  }
}

# CloudWatch Alarms for High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.scaling_events.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.saleor.name
  }

  tags = {
    Name = "${var.project_name}-high-cpu-alarm"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum", label = "Request Count" }],
            [".", "TargetResponseTime", { stat = "Average", label = "Response Time" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
            ["AWS/AutoScaling", "GroupDesiredCapacity", { stat = "Average", label = "Desired Capacity" }],
            [".", "GroupInServiceInstances", { stat = "Average", label = "In Service Instances" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Auto Scaling Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "RDS CPU" }],
            [".", "DatabaseConnections", { stat = "Average", label = "DB Connections" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Database Metrics"
        }
      }
    ]
  })
}

# S3 Bucket for ML Model and Metrics Storage
resource "aws_s3_bucket" "ml_data" {
  bucket = "${var.project_name}-ml-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-ml-data"
  }
}

resource "aws_s3_bucket_versioning" "ml_data" {
  bucket = aws_s3_bucket.ml_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_data" {
  bucket = aws_s3_bucket.ml_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Data source for account ID
data "aws_caller_identity" "current" {}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_predictive_scaling" {
  name = "${var.project_name}-lambda-predictive-scaling"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-predictive-scaling-role"
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_predictive_scaling" {
  name = "${var.project_name}-lambda-predictive-scaling-policy"
  role = aws_iam_role.lambda_predictive_scaling.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_data.arn,
          "${aws_s3_bucket.ml_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.scaling_events.arn
      }
    ]
  })
}

# Lambda Function (will be deployed with code later)
resource "aws_lambda_function" "predictive_scaling" {
  filename         = "${path.module}/../lambda/predictive_scaling.zip"
  function_name    = "${var.project_name}-predictive-scaling"
  role            = aws_iam_role.lambda_predictive_scaling.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = fileexists("${path.module}/../lambda/predictive_scaling.zip") ? filebase64sha256("${path.module}/../lambda/predictive_scaling.zip") : null
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      ASG_NAME           = aws_autoscaling_group.saleor.name
      S3_BUCKET          = aws_s3_bucket.ml_data.id
      SNS_TOPIC_ARN      = aws_sns_topic.scaling_events.arn
      MIN_INSTANCES      = var.min_size
      MAX_INSTANCES      = var.max_size
    }
  }

  tags = {
    Name = "${var.project_name}-predictive-scaling"
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}

# EventBridge Rule to trigger Lambda every 5 minutes
resource "aws_cloudwatch_event_rule" "predictive_scaling" {
  name                = "${var.project_name}-predictive-scaling-trigger"
  description         = "Triggers predictive scaling Lambda every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "${var.project_name}-predictive-scaling-trigger"
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "predictive_scaling" {
  rule      = aws_cloudwatch_event_rule.predictive_scaling.name
  target_id = "PredictiveScalingLambda"
  arn       = aws_lambda_function.predictive_scaling.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.predictive_scaling.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.predictive_scaling.arn
}
