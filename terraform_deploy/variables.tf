variable "dr_region" {
  description = "Region where DRS has been initialized and source servers replicating to"
  default     = "us-east-2"
}

variable "name" {
  description = "Prefix to use for resources creation"
  default     = "demo"
}

variable "tags" {
  description = "Tags to apply to resources"
  default     = {}
}

variable "cron_schedule" {
  description = "Cron Expression in UTC Time zone"
  default     = "cron(00 * * * ? *)"
}

variable "bucket_name" {
  description = "Bucket Name to crate and use for DRS Launch Templates"
  default     = "demo-drs-launch-templates"
}
