variable "name" {
  type        = string
  description = "The name of the instance. If empty, the config is used as the name."
  default     = ""
}
variable "project" {
  type        = string
  description = "The id of the project to deploy the instance in."
}
variable "config" {
  type        = string
  description = "The single-,dual-, or multi-region config to use, e.g. regional-europe-west1."
}
variable "admins" {
  type        = list(string)
  description = "Members have admin rights on the instance."
  default     = []
}
variable "viewers" {
  type        = list(string)
  description = "Members can view the instance."
  default     = []
}
variable "edition" {
  type        = string
  description = "Different editions provide different capabilities at different price points. Possible values: STANDARD (default), ENTERPRISE, ENTERPRISE_PLUS"
  default     = "STANDARD"
}
variable "processing_units" {
  type        = number
  description = "The number of processing units allocated to the main instance if edition was specified. Default is 100."
  default     = 100
}

locals {
  name = var.name == "" ? trimprefix(var.config, "regional-") : var.name
}

resource "google_spanner_instance" "main" {
  name                         = local.name
  project                      = var.project
  config                       = var.config
  display_name                 = local.name
  processing_units             = var.processing_units
  edition                      = var.edition
  default_backup_schedule_type = "NONE"
}

resource "google_spanner_instance_iam_member" "admins" {
  for_each = toset(var.admins)
  project  = var.project
  instance = google_spanner_instance.main.name
  role     = "roles/spanner.admin"
  member   = each.key
}

resource "google_spanner_instance_iam_member" "viewers" {
  for_each = toset(var.viewers)
  project  = var.project
  instance = google_spanner_instance.main.name
  role     = "roles/spanner.viewer"
  member   = each.key
}
