terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = var.kube_context
}

module "app1" {
  source   = "./modules/app"
  app_name = "app1"
  image    = "nginx:1.25"
  replicas = 2
}

module "app2" {
  source   = "./modules/app"
  app_name = "app2"
  image    = "httpd:2.4"
  replicas = 2
}
