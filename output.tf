/*output "kubernetes_endpoint" {
  description = "The cluster endpoint"
  sensitive   = true
  value       = module.gke.endpoint
}

output "client_token" {
  description = "The bearer token for auth"
  sensitive   = true
  value       = base64encode(data.google_client_config.default.access_token)
}

output "ca_certificate" {
  description = "The cluster ca certificate (base64 encoded)"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "service_account" {
  description = "The default service account used for running nodes."
  value       = module.gke.service_account
}

output "cluster_name" {
  description = "Cluster name"
  value       = module.gke.name
}

output "network_name" {
  description = "The name of the VPC being created"
  value       = module.gcp-network.network_name
}

output "subnet_name" {
  description = "The name of the subnet being created"
  value       = module.gcp-network.subnets_names
}

output "subnet_secondary_ranges" {
  description = "The secondary ranges associated with the subnet"
  value       = module.gcp-network.subnets_secondary_ranges
}

output "peering_name" {
  description = "The name of the peering between this cluster and the Google owned VPC."
  value       = module.gke.peering_name
}
output "project" {
  value = data.google_client_config.default
  sensitive = true
}
output "datacluster" {
  value       = data.google_container_cluster.primary
}
output "gke_auth" {
  value = module.gke_auth
  sensitive = true
}*/
/*output "update_token" {
  value = data.google_client_config.update.access_token
  sensitive = true
}*/
