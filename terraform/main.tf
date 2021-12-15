terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }

  backend "kubernetes" {
    secret_suffix = "state"
    config_path   = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "swagger-petstore" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "kubernetes_deployment" "swagger-petstore" {
  metadata {
    name      = format("%s-%d", var.metadata_name, var.build_number)
    namespace = kubernetes_namespace.swagger-petstore.metadata.0.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = var.application_name
      }
    }
    template {
      metadata {
        labels = {
          app = var.application_name
        }
      }
      spec {
        container {
          image = format("%s:%s", var.container_image, var.container_image_version)
          name  = "swagger-petstore-container"
          port {
            container_port = var.container_port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "swagger-petstore" {
  metadata {
    name      = var.metadata_name
    namespace = kubernetes_namespace.swagger-petstore.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.swagger-petstore.spec.0.template.0.metadata.0.labels.app
    }
    type = "NodePort"
    port {
      node_port   = var.node_port
      port        = var.container_port
      target_port = var.container_port
    }
  }
}