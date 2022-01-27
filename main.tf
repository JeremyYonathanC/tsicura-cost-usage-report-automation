module "naming_path_cache_table" {
  source        = "git@github.com:traveloka/terraform-aws-resource-naming.git?ref=v0.19.1"
  name_prefix   = "tsicura-path-cache"
  resource_type = "iam_role"
}

resource "aws_cloudwatch_event_rule" "trigger" {
  description         = "Trigger the report generation every 2nd day of the month"
  event_bus_name      = "default"
  is_enabled          = true
  name                = "trigger-tsicura-cost-usage-report-automation"
  schedule_expression = "cron(0 0 3 * ? *)"
  tags                = {}
  tags_all            = {}
}

resource "aws_cloudwatch_event_target" "sfn" {
  arn            = aws_sfn_state_machine.cost_usage_report_automation.arn
  event_bus_name = "default"
  role_arn       = module.cloudwatch_event_rule_role.role_arn
  rule           = aws_cloudwatch_event_rule.trigger.id
  target_id      = "TriggerSFNAutomation"
}

resource "aws_cloudwatch_event_rule" "trigger_slack_notification" {
  name        = "TSICURA-slack-notification-rule"
  description = "Rule for tsicura app to send notification to slack"

  event_pattern = <<EOF
{
  "source": ["aws.states"],
  "detail-type": ["Step Functions Execution Status Change"],
  "detail": {
    "status": ["FAILED", "SUCCEEDED"],
    "stateMachineArn": ["${aws_sfn_state_machine.cost_usage_report_automation.arn}"]
  }
}
EOF
}

 resource "aws_cloudwatch_event_target" "slack_notification" {
  arn            = module.GenerateSlackNotification.lambda_arn
  event_bus_name = "default"
  rule           = aws_cloudwatch_event_rule.trigger_slack_notification.id
  target_id      = "TriggerSlackNotificationAutomation"
}

module "cloudwatch_event_rule_role" {
  source                     = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v2.0.2"
  role_identifier            = "${var.service_name}-cloudwatcheventrule"
  role_description           = "Service Role for CloudWatch Event Rule"
  role_force_detach_policies = false
  aws_service                = "events.amazonaws.com"
  product_domain             = var.product_domain
  environment                = var.environment

  providers = {
    random = random
    aws    = aws
  }
}

resource "aws_dynamodb_table" "path_cache_table" {
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "path"
  name           = module.naming_path_cache_table.name
  read_capacity  = 0
  stream_enabled = false
  tags = {
    "Description"   = "tsicura cache table"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = module.naming_path_cache_table.name
    "ProductDomain" = "tsi"
    "Service"       = "tsicura"
    "Team"          = "tsi"
  }
  tags_all = {
    "Description"   = "tsicura cache table"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = module.naming_path_cache_table.name
    "ProductDomain" = "tsi"
    "Service"       = "tsicura"
    "Team"          = "tsi"
  }
  write_capacity = 0

  attribute {
    name = "path"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

}

resource "aws_ssm_parameter" "google_credentials_01" {
  data_type   = "text"
  description = "Cost Usage Report Generator - Google Credentials"
  key_id      = "alias/aws/ssm"
  name        = "/tvlk-secret/tsicura/tsi/google-credentials-01"
  tags = {
    "Description"   = "Cost Usage Report Generator - Google Credentials"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = "/tvlk-secret/tsicura/tsi/google-credentials-01"
    "ProductDomain" = "tsi"
  }
  lifecycle {
    ignore_changes = [value]
  }
  tags_all = {
    "Description"   = "Cost Usage Report Generator - Google Credentials"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = "/tvlk-secret/tsicura/tsi/google-credentials-01"
    "ProductDomain" = "tsi"
  }
  tier  = "Standard"
  type  = "SecureString"
  value = "placeholder"
}

resource "aws_ssm_parameter" "google_credentials_02" {
  data_type   = "text"
  description = "Cost Usage Report Generator - Google Credentials"
  key_id      = "alias/aws/ssm"
  name        = "/tvlk-secret/tsicura/tsi/google-credentials-02"
  tags = {
    "Description"   = "Cost Usage Report Generator - Google Credentials"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = "/tvlk-secret/tsicura/tsi/google-credentials-02"
    "ProductDomain" = "tsi"
  }
  lifecycle {
    ignore_changes = [value]
  }
  tags_all = {
    "Description"   = "Cost Usage Report Generator - Google Credentials"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = "/tvlk-secret/tsicura/tsi/google-credentials-02"
    "ProductDomain" = "tsi"
  }
  tier  = "Standard"
  type  = "SecureString"
  value = "placeholder"
}

module "sfn_cur_automation_role" {
  source                     = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v2.0.2"
  role_identifier            = "${var.service_name}-SFNRole"
  role_description           = "Service Role for SFN CUR"
  role_force_detach_policies = false
  aws_service                = "states.amazonaws.com"
  product_domain             = var.product_domain
  environment                = var.environment

  providers = {
    random = random
    aws    = aws
  }
}

resource "aws_iam_role_policy" "sfn_cost_usage_report_automation_role" {
  role   = module.sfn_cur_automation_role.role_name
  policy = data.aws_iam_policy_document.sfn_cost_usage_report_automation_policy.json
}

resource "aws_sfn_state_machine" "cost_usage_report_automation" {
  name     = "${var.service_name}-cost-usage-report-automation"
  role_arn = module.sfn_cur_automation_role.role_arn
  definition = <<EOF
  {
    "Comment": "A description of my state machine",
    "StartAt": "setQuery-GenerateReportStructure",
    "States": {
      "setQuery-GenerateReportStructure": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "OutputPath": "$.Payload",
        "Parameters": {
          "Payload.$": "$",
          "FunctionName": "${module.GenerateReportStructureSetQuery.lambda_arn}"
        },
        "Retry": [
          {
            "ErrorEquals": [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException"
            ],
            "IntervalSeconds": 2,
            "MaxAttempts": 6,
            "BackoffRate": 2
          }
        ],
        "Next": "Athena StartQueryExecution: GenerateReportStructure"
      },
      "Athena StartQueryExecution: GenerateReportStructure": {
        "Type": "Task",
        "Resource": "arn:aws:states:::athena:startQueryExecution",
        "Parameters": {
          "QueryExecutionContext": {
            "Catalog": "AwsDataCatalog",
            "Database": "hourly_datarefresh_parquet_dev2"
          },
          "QueryString.$": "$.query_string",
          "ResultConfiguration": {
            "OutputLocation": "s3://jeremy-testing-cura-2/1/Unsaved/2022/01/10/"
          },
          "WorkGroup": "primary"
        },
        "Next": "Wait (1)",
        "ResultPath": "$.QueryExecutionId"
      },
      "Wait (1)": {
        "Type": "Wait",
        "Seconds": 3,
        "Next": "Athena GetQueryResults: GenerateReportStructure"
      },
      "Athena GetQueryResults: GenerateReportStructure": {
        "Type": "Task",
        "Resource": "arn:aws:states:::athena:getQueryResults",
        "Parameters": {
          "QueryExecutionId.$": "$.QueryExecutionId.QueryExecutionId"
        },
        "Next": "GenerateReportStructure",
        "ResultPath": null
      },
      "GenerateReportStructure": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "OutputPath": "$.Payload",
        "Parameters": {
          "Payload.$": "$",
          "FunctionName": "${module.GenerateReportStructure.lambda_arn}"
        },
        "Retry": [
          {
            "ErrorEquals": [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException"
            ],
            "IntervalSeconds": 2,
            "MaxAttempts": 6,
            "BackoffRate": 2
          }
        ],
        "Next": "Choice"
      },
      "Choice": {
        "Type": "Choice",
        "Default": "StartProcessingReport",
        "Choices": [
          {
            "Not": {
              "Variable": "$.items",
              "IsPresent": true
            },
            "Next": "GenerateExecutionSummary"
          }
        ]
      },
      "StartProcessingReport": {
        "Type": "Map",
        "Iterator": {
          "StartAt": "SplitProcessing",
          "States": {
            "SplitProcessing": {
              "Type": "Parallel",
              "Branches": [
                {
                  "StartAt": "setQuery-ExportQueryGenerator",
                  "States": {
                    "setQuery-ExportQueryGenerator": {
                      "Type": "Task",
                      "Resource": "arn:aws:states:::lambda:invoke",
                      "OutputPath": "$.Payload",
                      "Parameters": {
                        "Payload.$": "$",
                        "FunctionName": "${module.GeneratePerItemReport_CUR_report_generator_setQuery.lambda_arn}"
                      },
                      "Retry": [
                        {
                          "ErrorEquals": [
                            "Lambda.ServiceException",
                            "Lambda.AWSLambdaException",
                            "Lambda.SdkClientException"
                          ],
                          "IntervalSeconds": 2,
                          "MaxAttempts": 6,
                          "BackoffRate": 2
                        }
                      ],
                      "Next": "Athena StartQueryExecution: ExportQueryGenerator"
                    },
                    "Athena StartQueryExecution: ExportQueryGenerator": {
                      "Type": "Task",
                      "Resource": "arn:aws:states:::athena:startQueryExecution",
                      "Parameters": {
                        "QueryExecutionContext": {
                          "Catalog": "AwsDataCatalog",
                          "Database": "hourly_datarefresh_parquet_dev2"
                        },
                        "QueryString.$": "$.result.query_string",
                        "ResultConfiguration": {
                          "OutputLocation": "s3://jeremy-testing-cura-2/1/Unsaved/2022/01/10/"
                        },
                        "WorkGroup": "primary"
                      },
                      "ResultPath": "$.QueryExecutionId",
                      "Next": "Wait"
                    },
                    "Wait": {
                      "Type": "Wait",
                      "Seconds": 6,
                      "Next": "Athena GetQueryResults: ExportQueryGenerator"
                    },
                    "Athena GetQueryResults: ExportQueryGenerator": {
                      "Type": "Task",
                      "Resource": "arn:aws:states:::athena:getQueryResults",
                      "Parameters": {
                        "QueryExecutionId.$": "$.QueryExecutionId.QueryExecutionId"
                      },
                      "Next": "ExportQueryGenerator",
                      "ResultPath": null
                    },
                    "ExportQueryGenerator": {
                      "Type": "Task",
                      "Resource": "arn:aws:states:::lambda:invoke",
                      "OutputPath": "$.Payload",
                      "Parameters": {
                        "Payload.$": "$",
                        "FunctionName": "${module.GeneratePerItemReport_CUR_report_generator.lambda_arn}"
                      },
                      "Retry": [
                        {
                          "ErrorEquals": [
                            "Lambda.ServiceException",
                            "Lambda.AWSLambdaException",
                            "Lambda.SdkClientException"
                          ],
                          "IntervalSeconds": 2,
                          "MaxAttempts": 6,
                          "BackoffRate": 2
                        }
                      ],
                      "End": true
                    }
                  }
                }
              ],
              "End": true
            }
          }
        },
        "ItemsPath": "$.items",
        "MaxConcurrency": 3,
        "Next": "GenerateExecutionSummary"
      },
      "GenerateExecutionSummary": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "OutputPath": "$.Payload",
        "Parameters": {
          "Payload.$": "$",
          "FunctionName": "${module.GenerateAutomationSummary.lambda_arn}"
        },
        "Retry": [
          {
            "ErrorEquals": [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException"
            ],
            "IntervalSeconds": 2,
            "MaxAttempts": 6,
            "BackoffRate": 2
          }
        ],
        "End": true
      }
    }
  }
  EOF
}

module "GenerateReportStructureSetQuery" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Report Structure Generator Set Query"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/report-structure-generator-setquery/"
  lambda_archive_directory_path = "${path.module}/dist/report-structure-generator-setquery.zip"
  lambda_description            = "This lambda is used to set the query for generating CUR report structure"
  lambda_layer_arns             = var.lambda_layer_arns

  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }
}

module "GenerateReportStructure" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Report Structure Generator"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/report-structure-generator/"
  lambda_archive_directory_path = "${path.module}/dist/report-structure-generator.zip"
  lambda_description            = "This lambda is used to generate CUR report structure"
  lambda_layer_arns             = var.lambda_layer_arns

  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }
}

module "GeneratePerItemReport_CUR_report_generator_setQuery" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Export Query Generator Set Query"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/export-query-setquery/"
  lambda_archive_directory_path = "${path.module}/dist/export-query-setquery.zip"
  lambda_description            = "This lambda is used to set the query for export query"
  lambda_layer_arns             = var.lambda_layer_arns

  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }
}

module "GeneratePerItemReport_CUR_report_generator" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Export Query Generator"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/export-query/"
  lambda_archive_directory_path = "${path.module}/dist/export-query.zip"
  lambda_description            = "This lambda is used for export query"
  lambda_layer_arns             = var.lambda_layer_arns

  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }
}

module "GenerateSlackNotification" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Slack Notification"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/slack-notification/"
  lambda_archive_directory_path = "${path.module}/dist/slack-notification.zip"
  lambda_description            = "This lambda is used to send notification to slack channel"
  lambda_layer_arns             = var.lambda_layer_arns

  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }
}

module "GenerateAutomationSummary" {
  source                        = "git@github.com:traveloka/terraform-aws-lambda.git?ref=v1.0.0"
  lambda_descriptive_name       = "Automation Summary Generator"
  product_domain                = var.product_domain
  service_name                  = var.service_name
  environment                   = var.environment
  lambda_timeout                = var.lambda_timeout
  log_retention_days            = var.log_retention_days
  is_local_archive              = "true"
  is_lambda_vpc                 = "false"
  lambda_memory_size            = var.lambda_memory_size
  lambda_runtime                = "python3.8"
  lambda_handler                = "main.handler"
  lambda_code_directory_path    = "${path.module}/application/automation-summary-generator/"
  lambda_archive_directory_path = "${path.module}/dist/automation-summary-generator.zip"
  lambda_description            = "This lambda is used to generate summary report of automation"
  lambda_layer_arns             = var.lambda_layer_arns
  lambda_environment_variables = {
    assume_role_arn                     = var.assume_role_arn
    athena_database_name                = var.athena_database_name
    athena_s3_bucket_query_result       = var.athena_s3_bucket_query_result
    "cost_usage_report_directory_id"    = var.cost_usage_report_directory_id
    "google_credentials_ssm_path"       = aws_ssm_parameter.google_credentials_01.name
    "google_credentials_temporary_json" = var.google_credentials_temporary_json
    "path_cache_table_arn"              = aws_dynamodb_table.path_cache_table.arn
    "path_cache_table_name"             = aws_dynamodb_table.path_cache_table.id
  }

  additional_tags = {
    "Description"   = "This lambda is used to generate summary report of automation"
    "Environment"   = "production"
    "ManagedBy"     = "terraform"
    "Name"          = "tsicura-automation-summary-generator-b6ad6ba318bf3e25"
    "ProductDomain" = "tsi"
  }
}

resource "aws_iam_role_policy" "GenerateAutomationSummary_policy" {
  name   = "terraform-20201125042437164400000001"
  policy = data.aws_iam_policy_document.additional_generator_policy.json
  role   = module.GenerateAutomationSummary.role_name
}

resource "aws_iam_role_policy" "GenerateReportStructure_policy" {
  role   = module.GenerateReportStructure.role_name
  policy = data.aws_iam_policy_document.additional_generator_policy.json
}

resource "aws_iam_role_policy" "GeneratePerItemReport_CUR_report_generator" {
  role   = module.GeneratePerItemReport_CUR_report_generator.role_name
  policy = data.aws_iam_policy_document.additional_generator_policy.json
}
