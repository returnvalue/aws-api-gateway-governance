# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# API Gateway: The entry point for our governed API
resource "aws_api_gateway_rest_api" "governed_api" {
  name        = "SysOps-Governance-API"
  description = "API with mandatory keys and usage plans"
}

# API Resource: A simple endpoint for our API
resource "aws_api_gateway_resource" "data_resource" {
  rest_api_id = aws_api_gateway_rest_api.governed_api.id
  parent_id   = aws_api_gateway_rest_api.governed_api.root_resource_id
  path_part   = "data"
}

# API Method: Defines the HTTP verb and security requirements
resource "aws_api_gateway_method" "get_data" {
  rest_api_id      = aws_api_gateway_rest_api.governed_api.id
  resource_id      = aws_api_gateway_resource.data_resource.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

# API Method Response: Defines the successful status code
resource "aws_api_gateway_method_response" "success" {
  rest_api_id = aws_api_gateway_rest_api.governed_api.id
  resource_id = aws_api_gateway_resource.data_resource.id
  http_method = aws_api_gateway_method.get_data.http_method
  status_code = "200"
}

# API Integration: A mock response for demonstration
resource "aws_api_gateway_integration" "mock_integration" {
  rest_api_id = aws_api_gateway_rest_api.governed_api.id
  resource_id = aws_api_gateway_resource.data_resource.id
  http_method = aws_api_gateway_method.get_data.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Integration Response: Returns the mock data
resource "aws_api_gateway_integration_response" "mock_response" {
  rest_api_id = aws_api_gateway_rest_api.governed_api.id
  resource_id = aws_api_gateway_resource.data_resource.id
  http_method = aws_api_gateway_method.get_data.http_method
  status_code = aws_api_gateway_method_response.success.status_code

  response_templates = {
    "application/json" = "{\"message\": \"Governed data retrieved successfully\"}"
  }
  
  depends_on = [aws_api_gateway_integration.mock_integration]
}

# API Deployment: Creates a point-in-time snapshot of the API
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.governed_api.id

  depends_on = [
    aws_api_gateway_integration.mock_integration,
    aws_api_gateway_integration_response.mock_response
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Stage: Represents an environment (e.g., 'prod') for the API
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.governed_api.id
  stage_name    = "prod"
}

# API Key: Unique identifier for an API consumer
resource "aws_api_gateway_api_key" "client_key" {
  name = "governed-client-key"
}

# Usage Plan: Defines throttling and quota limits for API keys
resource "aws_api_gateway_usage_plan" "standard_plan" {
  name         = "Standard-Usage-Plan"
  description  = "Limits clients to 10 requests per second and 5000 per month"

  api_stages {
    api_id = aws_api_gateway_rest_api.governed_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = 5000
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }
}

# Usage Plan Key: Associates the API key with the usage plan
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.client_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.standard_plan.id
}

# Outputs: Key identifiers for API governance
output "api_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/data"
}

output "api_key_value" {
  value     = aws_api_gateway_api_key.client_key.value
  sensitive = true
}
