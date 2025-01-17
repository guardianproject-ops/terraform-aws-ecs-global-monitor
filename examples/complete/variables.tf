variable "tailscale_tailnet" { type = string }
variable "tailscale_client_id" { type = string }
variable "tailscale_client_secret" { type = string }
variable "tailscale_tags_global_monitor" { type = list(string) }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnets_cidr" {
  type    = string
  default = "10.0.0.0/22"
}
