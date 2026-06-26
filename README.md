# AWS Terraform – Building a Compliant S3 Resource

## Project Overview

This project demonstrates how to deploy an AWS S3 environment using Terraform while implementing security and compliance controls aligned with NIST 800-53.

The objective was to transform a basic S3 deployment into a compliant cloud resource by implementing controls for:

- **SC-28:** Protection of Information at Rest
- **AC-3:** Access Enforcement
- **CM-6:** Configuration Settings
- **AU-3:** Audit Record Content
- **AU-6:** Audit Review and Analysis

---

## Architecture

![Architecture Diagram](images/architecture.png)

The environment consists of:

- Primary S3 Bucket
- Dedicated Log Bucket
- Server-Side Encryption
- Public Access Blocking
- Versioning
- Ownership Controls
- Access Logging

---

## Environment Setup

### Step 1 – Verified Terraform.exe download version & Login to AWS Sandbox Environment

Terraform was installed and verified through PowerShell. I also logged into my AWS sandbox

```powershell
terraform version
aws sts get-caller-identity
```

<img width="1896" height="510" alt="image" src="https://github.com/user-attachments/assets/cdc5b22b-8652-4cb6-b48d-c22b1719c289" />


### Step 2 – Navigate to Project Directory & Verify Contents

```powershell
cd C:\Users\<your-user>\Downloads\week-1
dir
```
<img width="1203" height="660" alt="image" src="https://github.com/user-attachments/assets/c86c94a7-6561-49a1-9bce-5a51c9b0ba84" />

---

### Step 3 – Initialize Terraform

```powershell
terraform init
```

Terraform successfully downloaded the required providers:

- `hashicorp/aws`
- `hashicorp/random`

<img width="1217" height="633" alt="image" src="https://github.com/user-attachments/assets/81ec5d73-29fc-49c4-bec9-6db7f67c535d" />


---

## Security Controls Implemented

## SC-28 – Protection of Information at Rest

### Objective

Ensure all data stored within the S3 buckets is encrypted at rest.

### Terraform Resource

```terraform
aws_s3_bucket_server_side_encryption_configuration
```

### Implementation

Encryption was enabled for both the primary bucket and the log bucket using `AES256`.

```terraform
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```
<img width="1070" height="522" alt="image" src="https://github.com/user-attachments/assets/47b67d09-2b2c-477d-81dc-a0cf25cebe1a" />

### Why AES256?

AES256 provides encryption at rest and satisfies the requirement for this lab.

In production environments, AWS KMS may be preferred when key rotation, auditability, separation of duties, or stronger compliance evidence is required.

Examples include:

- HIPAA
- PCI DSS
- FedRAMP
- Financial Services

<img width="1239" height="465" alt="image" src="https://github.com/user-attachments/assets/1e960e01-11e2-4cae-b98d-18e1eb004696" />


---

## AC-3 – Access Enforcement

### Objective

Prevent public exposure of bucket contents.

### Terraform Resource

```terraform
aws_s3_bucket_public_access_block
```
<img width="741" height="1140" alt="image" src="https://github.com/user-attachments/assets/6fb8df8c-889b-4504-bef3-9cbc3fe07e60" />

### Implementation

All four public access block settings were enabled for both buckets.

```terraform
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "log" {
  bucket = aws_s3_bucket.log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

AWS treats these as four independent public access protections. All four must be enabled to fully block public access.

<img width="823" height="774" alt="image" src="https://github.com/user-attachments/assets/59eb8b96-e6a2-46ac-b037-d48d6de41001" />

---

## CM-6 – Configuration Settings

### Objective

Enable object versioning for recovery and auditability.

### Terraform Resource

```terraform
aws_s3_bucket_versioning
```
<img width="981" height="1210" alt="image" src="https://github.com/user-attachments/assets/2a03d3ed-43cb-4f2c-9d7f-4eea0a37e360" />

### Implementation

Versioning was enabled on the primary bucket.

```terraform
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

### Benefits

- Object recovery
- Change tracking
- Audit support
- Protection against accidental deletion

<img width="857" height="1154" alt="image" src="https://github.com/user-attachments/assets/a39098d1-b31b-452f-bc6c-a35d17fe090d" />

---

## AU-3 / AU-6 – Audit Logging

### Objective

Capture and store S3 access logs for audit review.

### Terraform Resources

```terraform
aws_s3_bucket_ownership_controls
aws_s3_bucket_acl
aws_s3_bucket_logging
```
<img width="975" height="823" alt="image" src="https://github.com/user-attachments/assets/86c86203-efc8-4759-b4d7-e6e28a0028b8" />

### Implementation

Access logging was configured so the primary bucket sends logs to the dedicated log bucket.

```terraform
resource "aws_s3_bucket_ownership_controls" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log" {
  depends_on = [aws_s3_bucket_ownership_controls.log]

  bucket = aws_s3_bucket.log.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_logging" "primary" {
  depends_on = [aws_s3_bucket_acl.log]

  bucket = aws_s3_bucket.primary.id

  target_bucket = aws_s3_bucket.log.id
  target_prefix = "access-logs/"
}
```

### Why this order matters

The log bucket must allow the S3 log delivery group to write logs. On modern AWS S3 configurations, object ownership must be set first, then the ACL, then bucket logging.

<img width="746" height="961" alt="image" src="https://github.com/user-attachments/assets/b61b35fb-9119-4845-aec9-8b3f6edba7ec" />


---

## Validation

The Terraform configuration was formatted and validated successfully.

```powershell
terraform fmt
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

<img width="975" height="420" alt="image" src="https://github.com/user-attachments/assets/8da96849-ac75-4c55-b55b-8b6708d6e7b0" />


---

## Compliance Evidence

To provide machine-readable evidence for **SC-28**, an output was created that exposes the encryption algorithm configured on the primary bucket.

```terraform
output "bucket_name" {
  description = "Primary bucket name."
  value       = aws_s3_bucket.primary.id
}

output "bucket_arn" {
  description = "Primary bucket ARN."
  value       = aws_s3_bucket.primary.arn
}

output "encryption_algorithm" {
  description = "Encryption algorithm configured for the primary bucket."
  value = one([
    for rule in aws_s3_bucket_server_side_encryption_configuration.primary.rule :
    rule.apply_server_side_encryption_by_default[0].sse_algorithm
  ])
}
```

Expected output:

```text
AES256
```

This output demonstrates that encryption at rest was successfully configured.

<img width="797" height="652" alt="image" src="https://github.com/user-attachments/assets/cd51fb87-e0c1-4183-b5aa-4064f668a7d7" />


---

## Lessons Learned

- Terraform resources can be mapped directly to security controls.
- Compliance requirements can be implemented as code.
- Encryption at rest and key management serve different purposes.
- Public access blocking requires all four AWS protection settings.
- S3 logging has dependency requirements involving ownership controls and ACLs.
- Infrastructure as Code creates repeatable and auditable deployments.

---

## Technologies Used

- Terraform
- AWS S3
- AWS IAM
- PowerShell
- NIST 800-53

---

## Author

**Toke Atijosan**  
Cybersecurity Analyst | GRC Engineer | Agentic AI Security Engineer
