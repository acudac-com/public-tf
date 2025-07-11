variable "project_id" {
  type        = string
  description = "ID of the GCP project to create."
}
variable "parent_id" {
  type        = string
  description = "Parent org/folder id to create the project under."
}
variable "billing_account" {
  type        = string
  description = "Billing account ID to associate with the project."
}
variable "parent_is_folder" {
  type        = bool
  description = "Whether the parent_id is a folder instead of an organization."
  default     = false
}
variable "org_project" {
  type        = string
  description = "The organisation project which acts as the vpc host project and the project where artifacts like Docker images are stored. If specified, the create project becomes a vpc service project of the org_project and the serverless robot agent of this new project gets permission to read all artifacts in the org_project."
  default     = null
}

resource "google_project" "main" {
  name            = var.project_id
  project_id      = var.project_id
  org_id          = var.parent_is_folder ? null : var.parent_id
  folder_id       = var.parent_is_folder ? var.parent_id : null
  billing_account = var.billing_account
}

resource "google_project_service" "main" {
  project = google_project.main.project_id
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "spanner.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_service_project" "main" {
  count           = var.org_project != null ? 1 : 0
  host_project    = var.org_project
  service_project = google_project.main.project_id
}

resource "google_project_iam_member" "serverless_artifacts_reader" {
  count   = var.org_project != null ? 1 : 0
  project = var.org_project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:service-${google_project.main.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_logging_project_exclusion" "cloudrun_requests" {
  name        = "cloudrun-requests"
  project     = var.project_id
  description = "Exclude cloudrun request logs."
  filter      = "LOG_ID(\"run.googleapis.com/requests\")"
}
