variable "domain" {
  type    = string
  default = "sandbox.sixfeetup.com"
}

variable "api_domain" {
  type    = string
  default = "api.sandbox.sixfeetup.com"
}

variable "cluster_domain" {
  type    = string
  default = "k8s.sandbox.sixfeetup.com"
}

variable "argocd_domain" {
  type    = string
  default = "argocd.sandbox.sixfeetup.com"
}

variable "environment" {
  default = "sandbox"
}