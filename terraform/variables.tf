variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "lab-aap-prosperia"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "Nombre del key pair existente en AWS para SSH"
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs con acceso a la app y SSH (idealmente tu IP /32)"
  default     = ["0.0.0.0/0"]
}

variable "dd_api_key" {
  type      = string
  sensitive = true
}

variable "dd_site" {
  type    = string
  default = "datadoghq.com"
}

variable "repo_url" {
  type        = string
  description = "URL del repo de GitHub con el lab (se clona en el host)"
}
