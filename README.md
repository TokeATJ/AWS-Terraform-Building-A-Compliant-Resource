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

### Step 1 – Login to AWS Sandbox Environment &

Terraform was installed and verified through PowerShell.

```powershell
winget install Hashicorp.Terraform
terraform version
aws sts get-caller-identity
```

![Terraform Installation](images/terraform-install.png)

<img width="1175" height="535" alt="image" src="https://github.com/user-attachments/assets/23b0d22c-75e9-482f-915e-ac1097783b30" />

<img width="1896" height="510" alt="image" src="https://github.com/user-attachments/assets/64414d8b-5029-47d3-ad68-3fcb1ef73b97" />



### Step 2 – Navigate to Project Directory & Verify Contents

```powershell
cd C:\Users\<your-user>\Downloads\week-1
dir
```

<img width="1203" height="660" alt="image" src="https://github.com/user-attachments/assets/d1a77f30-8008-496e-a303-47652dd52001" />

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

![AC-3 Public Access Block](images/ac3-public-access.png)

---

## CM-6 – Configuration Settings

### Objective

Enable object versioning for recovery and auditability.

### Terraform Resource

```terraform
aws_s3_bucket_versioning
```

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

![CM-6 Versioning](images/cm6-versioning.png)

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

![Audit Logging](images/audit-logging.png)

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

![Terraform Validate](images/terraform-validate.png)

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

![Outputs](images/outputs.png)

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
