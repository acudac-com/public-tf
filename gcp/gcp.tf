variable "id" {
  type        = string
  description = "The organization ID for the GCP organization, e.g. 123456789"
}
variable "project" {
  type        = string
  description = "The id of the organization's project. Most of the time this will already exist and you need to import it first. This is the shared vpc host and where your docker images, dns zones, ssl certificates, spanner instance and loadbalancer will live."
}
variable "billing_account" {
  type        = string
  description = "The billing account ID to use for the host project, e.g. QW2GW3-123456-HTRU74H"
}
variable "domain" {
  type        = string
  description = "The domain to use for the bucket names and groups."
}
variable "region" {
  type        = string
  description = "The region to use for resources like the GCS buckets and the spanner instance (if edition specified). Default is europe-west1"
  default     = "europe-west1"
}
variable "customer_id" {
  type        = string
  description = "The google workspace or cloud identity customer id, e.g. C01234h"
}
variable "owners" {
  type        = list(string)
  description = "Members have full access to everything in the organisation."
}
variable "developers" {
  type        = list(string)
  default     = []
  description = "Members get access to development resources like the package development bucket and tasks queue."
}
variable "network_admins" {
  type        = list(string)
  default     = []
  description = "Members get full access to all networking related resources like loadbalancers, ip addresses etc."
}
variable "network_viewers" {
  type        = list(string)
  default     = []
  description = "Members can see all networking related resources like loadbalancers, ip addresses etc."
}

resource "google_organization_policy" "disabled" {
  for_each   = toset(["iam.disableServiceAccountKeyCreation"])
  org_id     = var.id
  constraint = each.key
  boolean_policy {
    enforced = false
  }
}

resource "google_project" "main" {
  name            = var.project
  project_id      = var.project
  org_id          = var.id
  billing_account = var.billing_account
}

resource "google_project_service" "main" {
  for_each = toset([
    "admin.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbilling.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "domains.googleapis.com",
    "certificatemanager.googleapis.com",
    "spanner.googleapis.com",
    "cloudidentity.googleapis.com",
  ])
  project            = google_project.main.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "main" {
  project = google_project.main.project_id
}

resource "google_cloud_identity_group" "owners" {
  display_name = "Organisation Owners"
  parent       = "customers/${var.customer_id}"
  description  = "Members have full access to everything in the organisation."
  group_key {
    id = "owners@${var.domain}"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "owners" {
  for_each = toset(var.owners)
  group    = google_cloud_identity_group.owners.id
  preferred_member_key {
    id = split(":", each.key)[1]
  }
  roles {
    name = "MEMBER"
  }
  roles {
    name = "OWNER"
  }
}

resource "google_organization_iam_member" "owners" {
  for_each = toset([
    "owner",
    "resourcemanager.folderAdmin",
    "resourcemanager.projectCreator",
    "storage.admin",
    "orgpolicy.policyAdmin",
    "compute.xpnAdmin"
  ])
  org_id = var.id
  role   = "roles/${each.key}"
  member = "group:${google_cloud_identity_group.owners.group_key[0].id}"
}

resource "google_cloud_identity_group" "developers" {
  display_name = "Organisation Developers"
  parent       = "customers/${var.customer_id}"
  description  = "Members get the Storage Writer role to the package-development bucket. Note that organisation owners, product owners and product developers are automatically added to this group."
  group_key {
    id = "developers@${var.domain}"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "developers" {
  for_each = toset(var.developers)
  group    = google_cloud_identity_group.developers.id
  preferred_member_key {
    id = split(":", each.key)[1]
  }
  roles {
    name = "MEMBER"
  }
}

// All terraform state for the organisation.
resource "google_storage_bucket" "tfstate" {
  name                     = "tfstate.${var.domain}"
  location                 = var.region
  project                  = var.project
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

// A bucket that all devs in the org have access to
resource "google_storage_bucket" "package_development" {
  name                        = "package-development.${var.domain}"
  location                    = var.region
  project                     = var.project
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  soft_delete_policy {} // disable soft delete
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

resource "google_storage_bucket_iam_member" "package_developers" {
  for_each   = toset(["group:developers@${var.domain}"])
  bucket     = google_storage_bucket.package_development.name
  role       = "roles/storage.objectAdmin"
  member     = each.key
  depends_on = [google_cloud_identity_group.developers]
}

resource "google_organization_iam_member" "network_admins" {
  for_each = toset(var.network_admins)
  org_id   = var.id
  role     = "roles/compute.networkAdmin"
  member   = each.key
}

resource "google_organization_iam_member" "network_viewers" {
  for_each = toset(var.network_viewers)
  org_id   = var.id
  role     = "roles/compute.networkViewer"
  member   = each.key
}
