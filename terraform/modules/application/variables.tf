variable "application" {
  default = "my-awesome-sixie-project"
}

variable "environment" {
  default = "sandbox"
}

variable "domain_zone" {
  default = "sixfeetup.com"
}

variable "api_domain" {
  type    = string
  default = "api.sixfeetup.com"
}

variable "cluster_domain" {
  default = "k8s.sixfeetup.com"
}

variable "cluster_public_id" {
  default = ""
}

variable "cluster_id" {
  default = ""
}

variable "cluster_arn" {
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
