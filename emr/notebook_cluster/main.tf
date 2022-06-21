locals {
  tags = { "tecton-accessible:${var.deployment_name}" : "true" }

  hive_config = [
    {
      Classification : "hive-site",
      Properties : {
        "hive.metastore.client.factory.class" : "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory",
        "hive.metastore.glue.catalogid" : var.glue_account_id
      }
    },
    {
      Classification : "spark-defaults",
      Properties : {
        "hive.metastore.client.factory.class" : "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory",
        "hive.metastore.glue.catalogid" : var.glue_account_id
      }
    },
    {
      Classification : "spark-hive-site",
      Properties : {
        "hive.metastore.client.factory.class" : "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory",
        "hive.metastore.glue.catalogid" : var.glue_account_id
      }
    }
  ]

  base_config = [
    {
      Classification : "livy-env",
      Properties : {}
      Configurations : [
        {
          Classification : "export",
          Properties : {
            "CLUSTER_REGION" : var.region,
            "TECTON_CLUSTER_NAME" : var.deployment_name
          }
        }
      ]
    },
    {
      Classification : "yarn-env",
      Properties : {},
      Configurations : [
        {
          Classification : "export",
          Properties : {
            "CLUSTER_REGION" : var.region,
            "TECTON_CLUSTER_NAME" : var.deployment_name
          }
        }
      ]
    }
  ]

  // bootstrap_regions
  // ---
  // EMR bootstrapping only supports bootstrap scripts from s3 buckets. The current way the s3
  // client within EMR is retrieving the bootstrap scripts causes a failure to retrieve the file in
  // certain regions. Currently Tecton supports serving bootstrap scripts from the following
  // regions. (including us-west-2 by default) Reach out to customer support for further information.
  bootstrap_regions = {
    "eu-central-1" : "-eu-central-1",
    "eu-west-1" : "-eu-west-1",
    "us-east-2" : "-us-east-2",
  }

  bootstrap_action = [
    {
      name = "tecton_emr_setup"
      path = format(
        "s3://tecton.ai.public%s/install_scripts/setup_emr_notebook_cluster_v2.sh",
        lookup(local.bootstrap_regions, var.region, ""),
      )
    }
  ]
}

resource "aws_emr_cluster" "cluster" {
  name          = "tecton-${var.deployment_name}-notebook-cluster"
  release_label = "emr-6.4.0"

  applications = ["Spark", "Livy", "Hive", "JupyterEnterpriseGateway"]

  ec2_attributes {
    subnet_id                         = var.subnet_id
    emr_managed_master_security_group = var.emr_security_group_id
    emr_managed_slave_security_group  = var.emr_security_group_id
    instance_profile                  = var.instance_profile_arn
    service_access_security_group     = var.emr_service_security_group_id
  }

  master_instance_group {
    instance_type = var.instance_type
  }

  core_instance_group {
    instance_type  = var.instance_type
    instance_count = var.instance_count

    ebs_config {
      size                 = var.ebs_size
      type                 = var.ebs_type
      volumes_per_instance = var.ebs_count
    }
  }

  dynamic "bootstrap_action" {
    iterator = bootstrap_action
    for_each = concat(local.bootstrap_action, var.extra_bootstrap_actions)
    content {
      name = lookup(bootstrap_action.value, "name", null)
      path = lookup(bootstrap_action.value, "path", null)
      args = lookup(bootstrap_action.value, "args", null)
    }
  }

  service_role = var.emr_service_role_id

  configurations_json = (var.has_glue ?
    jsonencode(concat(local.hive_config, local.base_config, var.extra_cluster_config)) :
    jsonencode(concat(local.base_config, var.extra_cluster_config))
  )

  step {
    action_on_failure = "TERMINATE_CLUSTER"
    name              = "Setup Hadoop Debugging"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = ["state-pusher-script"]
    }
  }

  # Auto scaling 
  autoscaling_policy      = var.autoscaling_policy
  autoscaling_role        = var.autoscaling_role
  auto_termination_policy = {
    idle_timeout = var.idle_timeout
  }

  tags = {
    notebook                                   = "true",
    "tecton-accessible:${var.deployment_name}" = "true",
    tecton-owned                               = "true"
  }
}

### AWS Secrets
resource "aws_secretsmanager_secret" "api_service" {
  name = "tecton-${var.deployment_name}/API_SERVICE"
}
resource "aws_secretsmanager_secret_version" "api_service" {
  secret_id     = aws_secretsmanager_secret.api_service.id
  secret_string = "https://${var.deployment_name}.tecton.ai/api"
}
resource "aws_secretsmanager_secret" "tecton_api_key" {
  name = "tecton-${var.deployment_name}/TECTON_API_KEY"
}
