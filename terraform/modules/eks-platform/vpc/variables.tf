variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}
