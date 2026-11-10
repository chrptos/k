# Terraform backend configuration is intentionally left partial because the
# bucket name/prefix depend on a GCS bucket the user creates themselves
# (see README "前提作業"). Supply the missing values at init time, e.g.:
#
#   terraform init \
#     -backend-config="bucket=<your-tfstate-bucket>" \
#     -backend-config="prefix=gke/dev"
terraform {
  backend "gcs" {}
}
