provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE Autopilot: no node pool management, pay-per-pod billing.
# Note: Autopilot restricts privileged workloads and enforces resource
# requests/limits on every Pod — relevant when adding future workloads.
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  release_channel {
    channel = "REGULAR"
  }

  # Autopilot manages node pools itself; deletion_protection off keeps
  # `terraform destroy` usable for this personal/dev foundation.
  deletion_protection = false
}
