variable "name" {
  type        = string
  description = "Name of the product e.g. acudac."
}
variable "org_project" {
  type        = string
  description = "The project id of this product's parent organisation. This is where the product's docker registry and bucket is deployed."
}
variable "region" {
  type        = string
  description = "The region to deploy the product's bucket and docker registry."
}
variable "domain" {
  type        = string
  description = "The organisation's domain which is used for bucket name suffixes and group emails."
}
variable "customer_id" {
  type        = string
  description = "The google workspace or cloud identity customer id, e.g. C01234h"
}
variable "builders" {
  type        = list(string)
  description = "Members can read and write to the product's bucket and docker registry."
}

resource "google_cloud_identity_group" "builders" {
  display_name = "Builders of the ${var.name} product"
  parent       = "customers/${var.customer_id}"
  description  = "Members have full access to everything in the organisation."
  group_key {
    id = "builders.${var.name}-product@${var.domain}"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "builders" {
  for_each = toset(var.builders)
  group    = google_cloud_identity_group.builders.id
  preferred_member_key {
    id = split(":", each.key)[1]
  }
  roles {
    name = "MEMBER"
  }
}

data "google_cloud_identity_group_lookup" "developers" {
  group_key {
    id = "developers@${var.domain}"
  }
}

resource "google_cloud_identity_group_membership" "developers" {
  group = data.google_cloud_identity_group_lookup.developers.name
  preferred_member_key {
    id = google_cloud_identity_group.builders.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_artifact_registry_repository" "main" {
  project       = var.org_project
  location      = var.region
  repository_id = var.name
  format        = "DOCKER"
  cleanup_policies {
    id     = "keep"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
  cleanup_policies {
    id     = "delete"
    action = "DELETE"
    condition {
      older_than = "30d"
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "builders" {
  project    = var.org_project
  repository = google_artifact_registry_repository.main.repository_id
  location   = var.region
  member     = "group:${google_cloud_identity_group.builders.group_key[0].id}"
  role       = "roles/artifactregistry.writer"
}

resource "google_storage_bucket" "main" {
  name                     = "${var.name}.${var.org_project}.${var.domain}"
  location                 = var.region
  project                  = var.org_project
  public_access_prevention = "enforced"
  versioning {
    enabled = true
  }
  soft_delete_policy {
    retention_duration_seconds = 604800 // 7 days
  }
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age                = 30
      num_newer_versions = 10
    }
  }
}

resource "google_storage_bucket_iam_member" "builders" {
  bucket = google_storage_bucket.main.name
  member = "group:${google_cloud_identity_group.builders.group_key[0].id}"
  role   = "roles/storage.objectAdmin"
}

resource "google_storage_managed_folder" "folder" {
  bucket = "tfstate.${var.domain}"
  name   = "${var.name}/"
}

resource "google_storage_managed_folder_iam_member" "builders" {
  bucket         = "tfstate.${var.domain}"
  managed_folder = google_storage_managed_folder.folder.name
  member         = "group:${google_cloud_identity_group.builders.group_key[0].id}"
  role           = "roles/storage.objectAdmin"
}

