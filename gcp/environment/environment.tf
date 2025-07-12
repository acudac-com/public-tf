variable "product" {
  type        = string
  description = "Name of the product e.g. graziemille."
}
variable "environment" {
  type        = string
  description = "Name of the environment e.g. prod."
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
variable "customer_id" {
  type        = string
  description = "The google workspace or cloud identity customer id, e.g. C01234h"
}
variable "deployers" {
  type        = list(string)
  description = "Members can read and write to the environment's bucket, cloudrun services and use its service account."
}

resource "google_cloud_identity_group" "deployers" {
  display_name = "Deployers of the ${var.environment} in ${var.product}"
  parent       = "customers/${var.customer_id}"
  description  = "Members can read and write to the environment's bucket, cloudrun services and use its service account."
  group_key {
    id = "deployers.${var.environment}.${var.product}.environments@${var.domain}"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "deployers" {
  for_each = toset(var.deployers)
  group    = google_cloud_identity_group.deployers.id
  preferred_member_key {
    id = split(":", each.key)[1]
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_service_account" "main" {
  project      = var.project
  account_id   = "${var.product}-${var.environment}"
  display_name = "${var.product}-${var.environment}"
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
    title = "Fine grained role access"
    // adding "role_" prefix in front of roles otherwise it clashes with schema name
    expression = "resource.type == \"spanner.googleapis.com/DatabaseRole\" && resource.name.endsWith(\"/role_${var.product}_${var.environment}\")"
  }
  member = "serviceAccount:${google_service_account.main.email}"
}

resource "google_storage_bucket" "main" {
  name     = "${var.environment}.${var.product}.environments.${var.domain}"
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
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.main.email}"
}

resource "google_storage_bucket_iam_member" "deployers" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectAdmin"
  member = "group:${google_cloud_identity_group.deployers.group_key[0].id}"
}


