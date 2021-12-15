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

resource "kubernetes_config_map" "agent-config-cm" {
  metadata {
    name      = "agent-config"
    namespace = kubernetes_namespace.swagger-petstore.metadata.0.name
  }

  data = {
    APPDYNAMICS_AGENT_APPLICATION_NAME : "Swagger-PetStore"
    APPDYNAMICS_AGENT_ACCOUNT_NAME : "swagger-petstore"
    APPDYNAMICS_CONTROLLER_HOST_NAME : "ptpacket.saas.appdynamics.com"
    APPDYNAMICS_CONTROLLER_PORT : "443"
    APPDYNAMICS_CONTROLLER_SSL_ENABLED : "true"
    APPDYNAMICS_AGENT_TIER_NAME : "swagger-petstore-api"
    APPDYNAMICS_JAVA_AGENT_REUSE_NODE_NAME : "true"
    APPDYNAMICS_JAVA_AGENT_REUSE_NODE_NAME_PREFIX : "appd"
  }
}

resource "kubernetes_secret" "appd-secret" {
  metadata {
    name      = "appd-secret"
    namespace = kubernetes_namespace.swagger-petstore.metadata.0.name
  }

  data = {
    access_key = "dib5mr0ihnko"
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
          env_from {
            config_map_ref {
              name = kubernetes_config_map.agent-config-cm.metadata.0.name
            }
          }
          env {
            name = "APPDYNAMICS_AGENT_ACCOUNT_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.appd-secret.metadata.0.name
                key  = "access_key"
              }
            }
          }
          env {
            name  = "JAVA_OPTS"
            value = " -Dappdynamics.agent.accountAccessKey=$(APPDYNAMICS_AGENT_ACCOUNT_ACCESS_KEY) -Dappdynamics.controller.hostName=$(APPDYNAMICS_CONTROLLER_HOST_NAME) -Dappdynamics.controller.port=$(APPDYNAMICS_CONTROLLER_PORT) -Dappdynamics.controller.ssl.enabled=$(APPDYNAMICS_CONTROLLER_SSL_ENABLED) -Dappdynamics.agent.accountName=$(APPDYNAMICS_AGENT_ACCOUNT_NAME) -Dappdynamics.agent.applicationName=$(APPDYNAMICS_AGENT_APPLICATION_NAME) -Dappdynamics.agent.tierName=$(APPDYNAMICS_AGENT_TIER_NAME) -Dappdynamics.agent.reuse.nodeName=true -Dappdynamics.agent.reuse.nodeName.prefix=$(APPDYNAMICS_AGENT_REUSE_NODE_NAME_PREFIX) -javaagent:/opt/appdynamics/javaagent.jar "
          }
          image_pull_policy = "IfNotPresent"
        }
        restart_policy = "Always"
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