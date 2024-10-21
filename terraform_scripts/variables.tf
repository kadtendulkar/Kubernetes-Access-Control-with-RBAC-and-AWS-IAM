variable vpc_cidr_block {}
variable env_prefix {}
variable kad_admin_access_key {}
variable kad_admin_secret_key {}
variable my_ip {}
variable path_to_key_pair {}
variable key_pair_name {}
variable "cluster_endpoint_public_access" {
  description = "Whether the EKS cluster endpoint should be publicly accessible"
  type        = bool
  default     = false
}
variable "create_cloudwatch_log_group" {
  description = "Determines whether to create the CloudWatch log group"
  type        = bool
  default     = true  # or false if you don't want to create by default
}
variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain CloudWatch Logs"
  type        = number
  default     = 7  # or any other value you prefer
}

