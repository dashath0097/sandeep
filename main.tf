terraform {
  required_providers {
    spacelift = {
      source  = "spacelift-io/spacelift"
      version = "~> 1.0"
    }
  }
}

provider "spacelift" {}

# Define the role ARN (replace with the role you created in Step 1)
locals {
  role_name = "spacelift-role"
  role_arn  = "arn:aws:iam::992382549591:role/demo3.0"
  stacks_to_attach = ["stack-1", "stack-2", "stack-3"]  # Update with your stack names
}

# Create Spacelift AWS Integration
resource "spacelift_aws_integration" "integration" {
  name                           = local.role_name
  role_arn                       = local.role_arn
  generate_credentials_in_worker = false
}

# Generate the External IDs required for IAM AssumeRole
data "spacelift_aws_integration_attachment_external_id" "integration" {
  for_each = toset(local.stacks_to_attach)

  integration_id = spacelift_aws_integration.integration.id
  stack_id       = each.key
  read           = true
  write          = true
}

# IAM Role Trust Policy (Auto-updated with External IDs)
resource "aws_iam_role" "role" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        "Principal" = {
          "AWS" : data.spacelift_account.current.aws_account_id
        },
        "Action" = "sts:AssumeRole",
        "Condition" = {
          "StringEquals" = {
            "sts:ExternalId" = [for i in values(data.spacelift_aws_integration_attachment_external_id.integration) : i.external_id]
          }
        }
      }
    ]
  })
}
