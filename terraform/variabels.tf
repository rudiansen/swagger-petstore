variable "kubernetes_namespace" {
  description = "The namespace in Kubernetes where the application will be deployed onto"
  default     = "default"
}

variable "container_image" {
  description = "The container image will be deployed to Kubernetes"
  default     = null
}

variable "application_name" {
  description = "The name of the application"
  default     = "Swagger-PetStore"
}

variable "metadata_name" {
  description = "The name of metadata"
  default     = "swagger-petstore"
}

variable "container_port" {
  description = "The port number of application in the container"
  type        = number
  default     = 8080
}

variable "node_port" {
  description = "The node port in Kubernetes for the application"
  type        = number
  default     = 30000
}

variable "container_image_version" {
  description = "The version of container image"
  default     = "latest"
}

variable "build_number" {
  description = "The build number of Jenkins pipeline"
  type        = number
  default     = 0
}