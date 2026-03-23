# athena.tf
data "aws_caller_identity" "current" {}

# [Comment]: 1. 아테나 쿼리 결과를 저장할 위치 세팅 (Workgroup 생성)
resource "aws_athena_workgroup" "flow_logs_wg" {
  name = "vpc-flow-logs-workgroup"

  configuration {
    result_configuration {
      # 버킷의 /athena-results/ 폴더로 자동 지정
      output_location = "s3://${aws_s3_bucket.vpc_flow_logs_storage.bucket}/athena-results/"
    }
  }
  force_destroy = true
}

resource "aws_glue_catalog_database" "flow_logs_db" {
  name = "vpc_flow_logs_db"
}

resource "aws_glue_catalog_table" "vpc_flow_logs_table" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.flow_logs_db.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.vpc_flow_logs_storage.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/ap-northeast-2/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = " "
      }
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "int"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start_time"
      type = "int"
    }
    columns {
      name = "end_time"
      type = "int"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
  }
}