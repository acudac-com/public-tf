variable "project" {
  type        = string
  description = "The id of the spanner instance's gcp project."
}
variable "instance" {
  type        = string
  description = "The name of the spanner instance."
}
variable "name" {
  type        = string
  description = "Name of the database, e.g. 'prod'"
}
variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether Terraform will be prevented from destroying the database. Defaults to true."
}
variable "version_retention_period" {
  type        = string
  default     = "1h"
  description = "How long to keep previous versions of changed or deleted data. Default is 1h."
}
variable "dialect" {
  type        = string
  default     = "GOOGLE_STANDARD_SQL"
  description = "The dialect of the Cloud Spanner Database with GOOGLE_STANDARD_SQL as the default. Possible values are GOOGLE_STANDARD_SQL and POSTGRESQL"
}
variable "backup_retention_period" {
  type        = string
  default     = "1209600s" // 14 days
  description = "How long to keep backups for. Default is 1209600s (14days). Set to empty string to disable backups."
}
variable "backup_cron_spec" {
  type        = string
  default     = "0 0 * * *" // Every day at midnight
  description = "The cron expression for when to run backups. Irrelevant if backup_retention_period set to empty string."
}
variable "admins" {
  type        = list(string)
  description = "Members have admin rights on the database."
  default     = []
}
variable "readers" {
  type        = list(string)
  description = "Members can read data in the database."
  default     = []
}

resource "google_spanner_database" "main" {
  project                  = var.project
  instance                 = var.instance
  name                     = var.name
  deletion_protection      = var.deletion_protection
  version_retention_period = var.version_retention_period
  database_dialect         = var.dialect
}

resource "google_spanner_backup_schedule" "main" {
  count              = var.backup_retention_period == "" ? 0 : 1
  project            = var.project
  instance           = var.instance
  database           = google_spanner_database.main.name
  name               = "main"
  retention_duration = var.backup_retention_period
  spec {
    cron_spec {
      text = var.backup_cron_spec
    }
  }
  full_backup_spec {
  }
}

resource "google_spanner_database_iam_member" "admins" {
  for_each = toset(var.admins)
  project  = var.project
  instance = var.instance
  database = google_spanner_database.main.name
  role     = "roles/spanner.databaseAdmin"
  member   = each.key
}

resource "google_spanner_database_iam_member" "viewers" {
  for_each = toset(var.readers)
  project  = var.project
  instance = var.instance
  database = google_spanner_database.main.name
  role     = "roles/spanner.databaseReader"
  member   = each.key
}
