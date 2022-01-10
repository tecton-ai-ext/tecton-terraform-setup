locals {
  tags            = { "tecton-accessible:${var.deployment_name}" : "true" }
}

data "template_file" "eks_policy_json" {
  template = file("${path.module}/../templates/eks_policy.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

data "template_file" "devops_policy_json" {
  template = file("${path.module}/../templates/devops_policy.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

data "template_file" "devops_eks_policy_json" {
  template = file("${path.module}/../templates/devops_eks_policy.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

data "template_file" "devops_elasticache_policy_json" {
  template = file("${path.module}/../templates/devops_elasticache_policy.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

data "template_file" "spark_policy_json" {
  template = file("${path.module}/../templates/spark_policy.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

data "template_file" "cross_account_databricks_json" {
  template = file("${path.module}/../templates/cross_account_databricks.json")
  vars = {
    ACCOUNT_ID      = var.account_id
    DEPLOYMENT_NAME = var.deployment_name
    REGION          = var.region
  }
}

# DEVOPS
resource "aws_iam_role" "devops_role" {
  name                 = "tecton-${var.deployment_name}-devops-role"
  tags                 = local.tags
  assume_role_policy   = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.tecton_assuming_account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "devops_policy" {
  name   = "tecton-${var.deployment_name}-devops-policy"
  policy = data.template_file.devops_policy_json.rendered
  tags   = local.tags
}

resource "aws_iam_policy" "devops_eks_policy" {
  name   = "tecton-${var.deployment_name}-devops-eks-policy"
  policy = data.template_file.devops_eks_policy_json.rendered
  tags   = local.tags
}

resource "aws_iam_policy" "devops_elasticache_policy" {
  count  = var.elasticache_enabled ? 1 : 0
  name   = "tecton-${var.deployment_name}-devops-elasticache-policy"
  policy = data.template_file.devops_elasticache_policy_json.rendered
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "devops_policy_attachment" {
  policy_arn = aws_iam_policy.devops_policy.arn
  role       = aws_iam_role.devops_role.name
}

resource "aws_iam_role_policy_attachment" "devops_eks_policy_attachment" {
  policy_arn = aws_iam_policy.devops_eks_policy.arn
  role       = aws_iam_role.devops_role.name
}

resource "aws_iam_role_policy_attachment" "devops_elasticache_policy_attachment" {
  count      = var.elasticache_enabled ? 1 : 0
  policy_arn = aws_iam_policy.devops_elasticache_policy[0].arn
  role       = aws_iam_role.devops_role.name
}

# EKS MANAGEMENT
resource "aws_iam_role" "eks_management_role" {
  name                 = "tecton-${var.deployment_name}-eks-management-role"
  tags                 = local.tags
  assume_role_policy   = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_management_policy" {
    for_each = toset([
        "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    ])
    policy_arn = each.value
    role = aws_iam_role.eks_management_role.name
}

# EKS NODE
resource "aws_iam_role" "eks_node_role" {
  name                 = "tecton-${var.deployment_name}-eks-worker-role"
  tags                 = local.tags
  assume_role_policy   = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "eks_node_policy" {
  name   = "tecton-${var.deployment_name}-eks-worker-policy"
  policy = data.template_file.eks_policy_json.rendered
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_attachment" {
  policy_arn = aws_iam_policy.eks_node_policy.arn
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
    for_each = toset([
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    ])
    policy_arn = each.value
    role = aws_iam_role.eks_node_role.name
}

provider "aws" {
  alias = "databricks-account"
}

# SPARK ROLE
resource "aws_iam_policy" "common_spark_policy" {
  provider = aws.databricks-account
  name   = "tecton-${var.deployment_name}-common-spark-policy"
  policy = data.template_file.spark_policy_json.rendered
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "common_spark_policy_attachment" {
  provider = aws.databricks-account
  policy_arn = aws_iam_policy.common_spark_policy.arn
  role       = var.spark_role_name
}

# CROSS-ACCOUNT ACCESS FOR SPARK
resource "aws_iam_role" "spark_cross_account_role" {
  name                 = "tecton-${var.deployment_name}-cross-account-spark-access"
  max_session_duration = 43200
  tags                 = local.tags
  assume_role_policy   = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.databricks_account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "cross_account_databricks_policy" {
  name   = "tecton-${var.deployment_name}-cross-account-databricks-policy"
  policy = data.template_file.cross_account_databricks_json.rendered
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "cross_account_databricks_policy_attachment" {
  policy_arn = aws_iam_policy.cross_account_databricks_policy.arn
  role       = aws_iam_role.spark_cross_account_role.name
}