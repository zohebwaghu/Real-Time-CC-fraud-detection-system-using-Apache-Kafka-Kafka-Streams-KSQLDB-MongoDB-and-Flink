# Minimal configuration: MSK + EMR Serverless + ECS Fargate producer, Neo4j Aura as external target.
# Copy this file to terraform.tfvars and customize values for your environment.

################################################################################
# Project Configuration
################################################################################

project     = "f1-streaming-graph"
environment = "dev"
region      = "us-east-1"

# Additional tags for all resources
tags = {
  Team        = "big-data-team"
  CostCenter  = "engineering"
  Application = "f1-analytics"
}

################################################################################
# VPC / Networking (reuse existing VPC)
################################################################################

# Provide existing networking primitives used by MSK, EMR, and ECS.
vpc_id             = "vpc-0bd2f3cb40130051b"
private_subnet_ids = ["subnet-0a15d2145a98e81df", "subnet-0be33526630ca1e7a", "subnet-0744c54c5589c494a"]

security_group_ids = {
  msk      = ""
  emr      = ""
  producer = ""
}

################################################################################
# Feature Flags (bare minimum: only MSK cluster)
################################################################################

create_msk          = true
create_emr          = false
create_ecs_producer = false

################################################################################
# Existing Resources (Discovery Override)
################################################################################

# Leave empty strings to let deployment create resources, or provide ARNs/names to reuse.
existing_bucket_names = {
  checkpoints = ""
  artifacts   = ""
  raw         = ""
}

existing_kms_keys = {
  data    = ""
  secrets = ""
  msk     = ""
}

existing_msk_cluster_arn  = "" # Provide ARN to reuse an existing MSK cluster
existing_emr_app_id       = "" # Provide EMR Serverless app ID if reusing
existing_neo4j_secret_arn = "" # ARN for Neo4j Aura credentials in Secrets Manager

################################################################################
# MSK Configuration (bare minimum compute)
################################################################################

msk_instance_type   = "kafka.t3.small" # Smallest instance type for minimal cost
msk_broker_count    = 3                # Required minimum for multi-AZ
msk_ebs_volume_size = 10               # Minimum EBS volume size (GB)
msk_kafka_version   = "3.6.0"

################################################################################
# EMR Configuration
################################################################################

# EMR Serverless release label
emr_release_label = "emr-7.10.0"

# EMR instance type reference (set to m5.large as requested). Note: EMR Serverless ignores EC2 instance types; this is provided for clarity or if switching to EMR on EC2.
emr_instance_type = "m5.large"

# Serverless capacity (workers) settings - MINIMAL for bare bones deployment
emr_initial_capacity = {
  driver = {
    cpu    = "1 vCPU"
    memory = "2 GB"
  }
  executor = {
    cpu    = "1 vCPU"
    memory = "2 GB"
  }
}

emr_maximum_capacity = {
  cpu    = "4 vCPU"
  memory = "8 GB"
}

emr_auto_start_enabled = true
emr_auto_stop_enabled  = true
emr_idle_timeout       = 60 # seconds (1 minute) - minimal for testing

################################################################################
# ECS Producer Configuration (Fargate)
################################################################################

ecs_producer_cpu    = 512
ecs_producer_memory = 1024
# ecs_producer_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/f1-producer:latest"

################################################################################
# Monitoring and lifecycle
################################################################################

enable_cloudwatch_logs = true
log_retention_days     = 7
enable_alarms          = true
alarm_email            = "alerts@example.com"
