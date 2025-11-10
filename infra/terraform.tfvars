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
vpc_id           = "vpc-0f2d2cd0ae1940418"
private_subnet_ids = ["subnet-0cab078a6cd0cbac1", "subnet-0c1e9d75e3c4c49d6", "subnet-0916e530e8d48e95e"]

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

existing_msk_cluster_arn = ""               # Provide ARN to reuse an existing MSK cluster
emr_existing_key_name    = ""               # Set to an existing AWS key pair name to reuse
emr_key_pair_name        = "macbook-air-m2" # Optional override when creating a new key pair
emr_ssh_public_key_path  = "~/.ssh/id_rsa.pub"
emr_ssh_ingress_cidrs    = ["68.250.225.30/32"] # Your current public IP for SSH access

################################################################################
# MSK Configuration (bare minimum compute)
################################################################################

msk_instance_type   = "kafka.t3.small" # Smallest instance type for minimal cost
msk_broker_count    = 3                # Required minimum for multi-AZ
msk_ebs_volume_size = 10               # Minimum EBS volume size (GB)
msk_kafka_version   = "3.6.0"

# Allow your laptop to connect to MSK (add your public IP)
msk_client_ingress_cidrs = ["68.250.225.30/32"]

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
