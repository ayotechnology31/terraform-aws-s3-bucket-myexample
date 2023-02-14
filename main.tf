resource "aws_s3_bucket" "b" {
  bucket = "my-tf-test-bucket-cl"
  acl    = "log-delivery-write"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }


  versioning {
      enabled = true
    }

  lifecycle_rule {
      id      = "log"
      enabled = true

      prefix = "log/"

      tags = {
        rule      = "log"
        autoclean = "true"
      }

      transition {
        days          = 30
        storage_class = "STANDARD_IA" 
      }

      transition {
        days          = 60
        storage_class = "GLACIER"
      }

      expiration {
        days = 90
      }
    }

    lifecycle_rule {
      id      = "tmp"
      prefix  = "tmp/"
      enabled = true

      expiration {
        date = "2016-01-12"
      }
    }
  }
  
  data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.example.iam_arn]
    }
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.b.id

  block_public_acls   = true
  ignore_public_acls =  true
  block_public_policy = true
  restrict_public_buckets = true

}
  resource "aws_s3_bucket_policy" "example" {
    bucket = aws_s3_bucket.b.id
    policy = data.aws_iam_policy_document.s3_policy.json
  }


  resource "aws_cloudfront_origin_access_identity" "test" {
      comment = "my-tf-test-bucket-cl.s3.us-east-1.amazonaws.com"//"This is my-tf-test origin access identity."
  }


  locals {
      s3_origin_id = aws_s3_bucket.b.bucket_regional_domain_name
  }

  resource "aws_cloudfront_distribution" "s3_distribution" {
    origin {
      domain_name = aws_s3_bucket.b.bucket_regional_domain_name
      origin_id   = local.s3_origin_id

      s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.example.cloudfront_access_identity_path
      }
    }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "my-tf-test cloud distribution"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "my-tf-test-bucket-cl.s3.amazonaws.com"
    prefix          = "myprefix"
  }
  
  //aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  =  ["GET", "HEAD", "OPTIONS"]
    cached_methods   =  ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
      geo_restriction {
        restriction_type = "none"
      }
    }


  viewer_certificate {
      cloudfront_default_certificate = true
      minimum_protocalol_version = "TLSv1.2_2021"
  }

    tags = {
    Environment = "dev"
  }
}