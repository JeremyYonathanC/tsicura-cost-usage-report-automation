variable environment {
  type = string
}

variable product_domain {
  type = string
}

variable service_name {
  type = string
}

variable google_credentials_temporary_json {
  type = string
}

variable lambda_timeout {
  type = string
}

variable lambda_memory_size {
  type = string
}

variable log_retention_days {
  type = string
}

variable assume_role_arn {
  type = string
}

variable athena_s3_bucket_query_result {
  type = string
}

variable athena_database_name {
  type = string
}

variable kms_key_id {
  type = string
}

variable cost_usage_report_directory_id {
  type = string
}

variable lambda_layer_arns {
  type    = list(string)
  default = []
}