variable "product" {
  type        = string
  description = "Name of the product e.g. graziemille."
}
variable "project" {
  type        = string
  description = "The ids of the google projects into which this product is deployed."
}
variable "region" {
  type        = string
  description = "The region to deploy the environment's bucket in."
}
variable "domain" {
  type        = string
  description = "The domain to use for the environment's bucket name."
}
variable "spanner_project" {
  type        = string
  description = "The project of the spanner instance that will be used by this environment."
}
variable "spanner_instance" {
  type        = string
  description = "The name of the spanner instance that will be used by this environment."
}
variable "spanner_database" {
  type        = string
  description = "The database of the spanner instance that will be used by this environment."
}

resource "google_service_account" "main" {
  project      = var.project
  account_id   = "${var.product}-main"
  display_name = "${var.product}-main"
}

resource "google_spanner_database_iam_member" "fine_grained_user" {
  project  = var.spanner_project
  instance = var.spanner_instance
  database = var.spanner_database
  role     = "roles/spanner.fineGrainedAccessUser"
  member   = "serviceAccount:${google_service_account.main.email}"
}

resource "google_spanner_database_iam_member" "database_role_user" {
  project  = var.spanner_project
  instance = var.spanner_instance
  database = var.spanner_database
  role     = "roles/spanner.databaseRoleUser"
  condition {
    title      = "Fine grained role access"
    expression = "resource.type == \"spanner.googleapis.com/DatabaseRole\" && resource.name.endsWith(\"/${var.product}\")"
  }
  member = "serviceAccount:${google_service_account.main.email}"
}

resource "google_storage_bucket" "main" {
  name     = "${var.product}.${var.project}.${var.domain}"
  project  = var.project
  location = var.region

  soft_delete_policy {
    retention_duration_seconds = 604800 // 7 days
  }
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true

  // delete non-current objects older than 3 days
  lifecycle_rule {
    condition {
      age                = 3
      num_newer_versions = 1
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "main" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.main.email}"
}


