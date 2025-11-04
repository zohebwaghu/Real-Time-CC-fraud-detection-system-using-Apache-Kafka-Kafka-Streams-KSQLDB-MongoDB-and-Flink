# Minimal configuration: MSK + EMR cluster.
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
vpc_id           = "vpc-02db9c3fb86743ea2"
private_subnet_ids = ["subnet-00b1f0fbdd50c0061", "subnet-07ab6b699f6df414f", "subnet-048c2a0d21b8822dd"]

security_group_ids = {
  msk = ""
  emr = ""
}

################################################################################
# Feature Flags (bare minimum: only MSK cluster)
################################################################################

create_msk         = true
create_emr_cluster = true

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
  data = ""
  msk  = ""
}

existing_msk_cluster_arn = "" # Provide ARN to reuse an existing MSK cluster

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
emr_cluster_release_label        = "emr-7.10.0"
emr_cluster_master_instance_type = "m4.large"
emr_cluster_core_instance_type   = "m4.large"
emr_cluster_core_instance_count  = 2
################################################################################
# Monitoring and lifecycle
################################################################################

enable_cloudwatch_logs = true
log_retention_days     = 7
enable_alarms          = true
alarm_email            = "alerts@example.com"
