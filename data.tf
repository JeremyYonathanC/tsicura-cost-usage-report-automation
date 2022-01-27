data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_kms_key" "kms_key" {
  key_id = var.kms_key_id
}

data "aws_iam_policy_document" "sfn_cost_usage_report_automation_policy" {

  statement {
    sid    = "AllowCreateLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowInvokeLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowAccessQueryResult"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:PutObject",
      "s3:CreateBucket",
    ]

    resources = ["*"]
  }

   statement {
    sid    = "AllowGetDataFromCostExplorer"
    effect = "Allow"

    actions = [
      "ce:GetCostAndUsage",
      "ce:GetDimensionValues",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowGetDataFromAthena"
    effect = "Allow"

    actions = [
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:ListQueryExecutions",
      "athena:GetDataCatalog",
      "athena:GetDatabase",
      "athena:ListDataCatalogs",
      "athena:ListDatabases",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowGlue"
    effect = "Allow"

    actions = [
      "glue:GetPartitions",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetDatabase",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowXRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = [
      "*"
    ]
  }

}

data "aws_iam_policy_document" "additional_generator_policy" {
  statement {
    sid    = "AllowAssumeRole"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    resources = [
      var.assume_role_arn
    ]
  }

  statement {
    sid    = "AllowCreateLogGroup"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    sid    = "AllowAccessPathCacheTable"
    effect = "Allow"

    actions = [
    "dynamodb:*"]

    resources = [
      aws_dynamodb_table.path_cache_table.arn
    ]
  }

  statement {
    sid    = "AllowCreateLogStram"
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
    ]
  }

  statement {
    sid    = "AllowGetParameterStore"
    effect = "Allow"

    actions = [
      "ssm:GetParameter*",
    ]

    resources = [
      aws_ssm_parameter.google_credentials_01.arn,
      aws_ssm_parameter.google_credentials_02.arn
    ]
  }

  statement {
    sid    = "AllowAccessQueryResult"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:PutObject",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowEncryptDecryptDescribe"

    actions = [
      "kms:DescribeKey",
      "kms:Decrypt",
    ]

    effect = "Allow"

    resources = [data.aws_kms_key.kms_key.arn]
  }
}