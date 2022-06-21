variable "deployment_name" {
  type        = string
  description = "This will be the same deployment name as used in the Tecton cluster installation"
}

variable "region" {
  type        = string
  description = "AWS region, e.g. us-east-1"
}

variable "instance_type" {
  type        = string
  default     = "m5.xlarge"
  description = "EMR EC2 instance type"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of EMR EC2 CORE instances to launch"
}

variable "ebs_size" {
  type        = string
  default     = "40"
  description = "Size of EBS volumes attached to EMR instances"
}

variable "ebs_type" {
  type        = string
  default     = "gp2"
  description = "Type of EBS volumes attached to EMR instances"
}

variable "ebs_count" {
  type        = number
  default     = 1
  description = "Number of EBS volumes attached to EMR instances"
}

variable "subnet_id" {
  type        = string
  description = "Subnet to install EMR into"
}
variable "instance_profile_arn" {
  type        = string
  description = "Underlying EC2 instance profile to use"
}
variable "emr_service_role_id" {
  type        = string
  description = "EMR service role"
}
variable "emr_security_group_id" {
  type        = string
  description = "EMR security group"
}
variable "emr_service_security_group_id" {
  type        = string
  description = "EMR service security group"
}
variable "extra_bootstrap_actions" {
  type        = list(any)
  description = "Additional bootstrap actions to perform upon EMR creation"
  default     = []
}
variable "extra_cluster_config" {
  type        = list(any)
  description = "Additional EMR cluster configurations"
  default     = []
}
variable "has_glue" {
  type        = bool
  description = "Set to true if AWS Glue Catalog is set up and should be used to load Hive tables"
}
variable "glue_account_id" {
  type        = string
  description = "AWS account id containing the AWS Glue Catalog for cross-account access"
}
variable "idle_timeout" {
  type         = number
  default      = 3600
  description  = "Idle time in seconds after which a cluster automatically terminates."
}
variable "autoscaling_role" {
  type         = string
  default      = null # "EMR_AutoScaling_DefaultRole"
  description  = "IAM role for automatic scaling policies." 
}
variable "autoscaling_policy" {
  type         = string
  default      = null # Must have both scale out/in https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-automatic-scaling.html
  description  = "String containing the EMR Auto Scaling Policy JSON."
}