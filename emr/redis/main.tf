resource "aws_elasticache_subnet_group" "tecton_redis_cluster_subnet_group" {
  name       = "tecton-redis-cluster-cache-subnet"
  subnet_ids = [var.redis_subnet_id]
  tags = {
      "tecton-accessible:${var.deployment_name}" = "true"
      }
}

resource "aws_elasticache_replication_group" "tecton_redis_cluster" {
  replication_group_id          = "tecton-redis-cluster"
  replication_group_description = "tecton-redis-replication-group"
  node_type                     = "cache.m5.xlarge"
  port                          = 6379
  automatic_failover_enabled    = true
  engine                        = "redis"
  engine_version                = "6.x"
  multi_az_enabled              = true
  parameter_group_name          = "default.redis6.x.cluster.on"
  # Enable TLS
  transit_encryption_enabled = "true"
  # Four shards. One replica per shard.
  cluster_mode {
    replicas_per_node_group = 1
    num_node_groups         = 4
  }
  security_group_ids = [var.redis_security_group_id]
  subnet_group_name  = "tecton-redis-cluster-cache-subnet"
  depends_on         = [aws_elasticache_subnet_group.tecton_redis_cluster_subnet_group]
  tags = {
      "tecton-accessible:${var.deployment_name}" = "true"
      }
}