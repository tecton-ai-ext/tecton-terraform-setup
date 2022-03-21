# this example assumes that Databricks and Tecton are deployed to the same account in the SaaS model and separate accounts in the VPC model for illustrative purposes

# Fill these in
variable "deployment_name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "spark_role_name" {
  type = string
}

variable "tecton_dataplane_account_role_arn" {
  type = string
}

variable "external_databricks_account_id" {
  type    = string
  default = ""
}

variable "external_databricks_account_role_arn" {
  type    = string
  default = ""
}

variable "is_vpc_deployment" {
  type    = bool
  default = false
}

variable "elasticache_enabled" {
  type    = bool
  default = false
}

variable "enable_eks_ingress_vpc_endpoint" {
  default     = true
  description = "Whether or not to enable resources supporting the EKS Ingress VPC Endpoint for in-VPC communication. EKS Ingress VPC Endpoint should always be enabled if the load balancer will not be public. Default: true."
  type        = bool
}

variable "ip_whitelist" {
  description = "Ip ranges that should be able to access Tecton endpoint"
  default     = ["0.0.0.0/0"]
}

variable "tecton_assuming_account_id" {
  type        = string
  description = "Get this from your Tecton rep"
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = var.tecton_dataplane_account_role_arn
  }
}

provider "aws" {
  alias  = "databricks-account"
  region = var.region
  assume_role {
    role_arn = var.external_databricks_account_role_arn
  }
}

resource "random_id" "external_id" {
  byte_length = 16
}

module "tecton" {
  providers = {
    aws = aws
  }
  count                      = var.is_vpc_deployment ? 0 : 1
  source                     = "../deployment"
  deployment_name            = var.deployment_name
  account_id                 = var.account_id
  tecton_assuming_account_id = var.tecton_assuming_account_id
  region                     = var.region
  cross_account_external_id  = random_id.external_id.id
  databricks_spark_role_name = var.spark_role_name
}

module "tecton_vpc" {
  providers = {
    aws                    = aws
    aws.databricks-account = aws.databricks-account
  }
  count                           = var.is_vpc_deployment ? 1 : 0
  source                          = "../vpc_deployment"
  deployment_name                 = var.deployment_name
  enable_eks_ingress_vpc_endpoint = var.enable_eks_ingress_vpc_endpoint
  account_id                      = var.account_id
  region                          = var.region
  spark_role_name                 = var.spark_role_name
  databricks_account_id           = var.external_databricks_account_id
  tecton_assuming_account_id      = var.tecton_assuming_account_id
  elasticache_enabled             = var.elasticache_enabled
}

# optionally, use a Tecton default vpc/subnet configuration
module "subnets" {
  providers = {
    aws = aws
  }
  count           = var.is_vpc_deployment ? 1 : 0
  source          = "../eks/vpc_subnets"
  deployment_name = var.deployment_name
  region          = var.region
  # Please make sure your region has enough AZs: https://aws.amazon.com/about-aws/global-infrastructure/regions_az/
  availability_zone_count = 3
}

module "security_groups" {
  providers = {
    aws = aws
  }
  count                           = var.is_vpc_deployment ? 1 : 0
  source                          = "../eks/security_groups"
  deployment_name                 = var.deployment_name
  enable_eks_ingress_vpc_endpoint = var.enable_eks_ingress_vpc_endpoint
  cluster_vpc_id                  = module.subnets[0].vpc_id
  ip_whitelist                    = concat([for ip in module.subnets[0].eks_subnet_ips : "${ip}/32"], var.ip_whitelist)
  tags                            = { "tecton-accessible:${var.deployment_name}" : "true" }
}
