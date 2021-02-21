terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "null_resource" "build" {
  triggers = {
    main    = base64sha256(file("${path.module}/src/main.go"))
    execute = base64sha256(file("${path.module}/build.sh"))
  }
  provisioner "local-exec" {
    command = "${path.module}/build.sh ${path.module}/src"
  }
}

data "archive_file" "source" {
  type        = "zip"
  source_file = "${path.module}/main"
  output_path = "${path.module}/lambda.zip"
  depends_on  = [null_resource.build]
}

resource "aws_iam_role" "lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "fhir" {
  function_name = "fhir"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = data.archive_file.source.output_base64sha256

  role = aws_iam_role.lambda.arn

  handler = "main"
  runtime = "go1.x"

  timeout = 120
  publish = true

  environment {
    variables = {
      HASH = base64sha256(file("src/main.go"))
    }
  }

  lifecycle {
    ignore_changes = [last_modified]
  }
}