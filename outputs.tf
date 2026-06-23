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

# TODO (SC-28 attestation): once you add the encryption configuration, add an
# output that surfaces the algorithm in effect (for example "AES256"). This is
# your machine-readable proof of encryption at rest.
