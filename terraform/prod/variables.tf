variable "domain" {
  type    = string
  default = "sixfeetup.com"
}

variable "api_domain" {
  type    = string
  default = "api.sixfeetup.com"
}

variable "cluster_domain" {
  type    = string
  default = "k8s.sixfeetup.com"
}

variable "argocd_domain" {
  type    = string
  default = "argocd.sixfeetup.com"
}

variable "environment" {
  default = "prod"
}
