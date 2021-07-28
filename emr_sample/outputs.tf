output "deployment_name" {
  value = local.deployment_name
}
output "region" {
  value = local.region
}
output "cross_account_role_arn" {
  value = module.tecton.cross_account_role_arn
}
output "cross_account_external_id" {
  value = resource.random_id.external_id.id
}
output "spark_role_name" {
  value = module.tecton.spark_role_name
}
output "emr_master_role_name" {
  value = module.tecton.emr_master_role_name
}
