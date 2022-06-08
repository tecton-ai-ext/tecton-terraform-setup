variable "redis_subnet_id" {
  type        = string
  description = "Subnet to install Redis into"
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group for Redis"
}

variable "deployment_name" {
  type = string
}