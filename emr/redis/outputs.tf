output "redis_configuration_endpoint" {
  value = aws_elasticache_replication_group.tecton_redis_cluster.configuration_endpoint_address
}