# AWS API Gateway Governance & Throttling Lab

This lab demonstrates a mission-critical API management pattern for the **AWS SysOps Administrator Associate**: implementing governance, security, and usage controls at the API layer.

## Architecture Overview

The system implements a production-grade API governance model:

1.  **Centralized Entry Point:** An API Gateway REST API serves as the front door for backend services (simulated with a MOCK integration).
2.  **Mandatory Identification:** Every request to the \`/data\` endpoint must include a valid **API Key** in the \`x-api-key\` header.
3.  **Usage Plans:** A logical container that associates API Keys with specific tiers of access.
4.  **Throttling & Quotas:**
    -   **Throttling:** Limits the rate of requests (10 per second with a burst of 20) to protect backend services from surges.
    -   **Quotas:** Limits the total number of requests (5000 per month) to manage costs and prevent abuse.
5.  **Lifecycle Management:** Uses **Stages** (e.g., \`prod\`) to manage different versions and environments of the API.

## Key Components

-   **API Gateway REST API:** The core orchestration service.
-   **API Keys:** Client-specific identifiers for authentication and tracking.
-   **Usage Plans:** The engine for enforcing throttling and monthly quotas.
-   **Mock Integration:** Provides a consistent, serverless response for testing the governance layer.

## Prerequisites

-   [Terraform](https://www.terraform.io/downloads.html)
-   [LocalStack Pro](https://localstack.cloud/)
-   [AWS CLI / awslocal](https://github.com/localstack/awscli-local)

## Deployment

1.  **Initialize and Apply:**
    ```bash
    terraform init
    terraform apply -auto-approve
    ```

## Verification & Testing

To test the API governance and throttling:

1.  **Attempt Access Without Key (Should Fail):**
    ```bash
    curl -I $(terraform output -raw api_url)
    ```
    Confirm you receive a \`403 Forbidden\` or \`401 Unauthorized\`.

2.  **Access with Valid API Key:**
    Retrieve the key value:
    ```bash
    terraform output -raw api_key_value
    ```
    Then, use the key in your request:
    ```bash
    curl -H "x-api-key: <YOUR_KEY_VALUE>" $(terraform output -raw api_url)
    ```

3.  **Test Throttling (Conceptual):**
    Rapidly sending more than 10 requests per second would trigger the usage plan's throttling limits, resulting in a \`429 Too Many Requests\` response.

## Cleanup

To tear down the infrastructure:
```bash
terraform destroy -auto-approve
```

---

💡 **Pro Tip: Using `aws` instead of `awslocal`**

If you prefer using the standard `aws` CLI without the `awslocal` wrapper or repeating the `--endpoint-url` flag, you can configure a dedicated profile in your AWS config files.

### 1. Configure your Profile
Add the following to your `~/.aws/config` file:
```ini
[profile localstack]
region = us-east-1
output = json
# This line redirects all commands for this profile to LocalStack
endpoint_url = http://localhost:4566
```

Add matching dummy credentials to your `~/.aws/credentials` file:
```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### 2. Use it in your Terminal
You can now run commands in two ways:

**Option A: Pass the profile flag**
```bash
aws iam create-user --user-name DevUser --profile localstack
```

**Option B: Set an environment variable (Recommended)**
Set your profile once in your session, and all subsequent `aws` commands will automatically target LocalStack:
```bash
export AWS_PROFILE=localstack
aws iam create-user --user-name DevUser
```

### Why this works
- **Precedence**: The AWS CLI (v2) supports a global `endpoint_url` setting within a profile. When this is set, the CLI automatically redirects all API calls for that profile to your local container instead of the real AWS cloud.
- **Convenience**: This allows you to use the standard documentation commands exactly as written, which is helpful if you are copy-pasting examples from AWS labs or tutorials.
