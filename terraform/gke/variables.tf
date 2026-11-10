variable "project_id" {
  description = "GCP project ID to deploy the GKE cluster into."
  type        = string
}

variable "region" {
  description = "GCP region for the GKE Autopilot cluster."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE Autopilot cluster."
  type        = string
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace where the External Secrets Operator (and its KSA) will run."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_ksa_name" {
  description = "Kubernetes ServiceAccount name used by External Secrets Operator, bound to the GCP service account via Workload Identity."
  type        = string
  default     = "external-secrets"
}
