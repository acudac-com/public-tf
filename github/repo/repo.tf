terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.6.0"
    }
  }
}

variable "name" {
  type = string
}
variable "description" {
  type = string
}
variable "public" {
  type = bool
}
variable "license" {
  type    = string
  default = "mit"
}
variable "pullers" {
  type    = list(string)
  default = []
}
variable "pushers" {
  type    = list(string)
  default = []
}
variable "maintainers" {
  type    = list(string)
  default = []
}
variable "triagers" {
  type    = list(string)
  default = []
}
variable "admins" {
  type    = list(string)
  default = []
}

resource "github_repository" "main" {
  name = var.name

  description          = var.description
  visibility           = var.public ? "public" : "private"
  auto_init            = true
  vulnerability_alerts = true
  license_template     = var.license
}

resource "github_repository_collaborators" "main" {
  repository = github_repository.main.name
  dynamic "user" {
    for_each = toset(var.pullers)
    content {
      permission = "pull"
      username   = each.key
    }
  }
  dynamic "user" {
    for_each = toset(var.pushers)
    content {
      permission = "push"
      username   = each.key
    }
  }
  dynamic "user" {
    for_each = toset(var.maintainers)
    content {
      permission = "maintain"
      username   = each.key
    }
  }
  dynamic "user" {
    for_each = toset(var.triagers)
    content {
      permission = "triage"
      username   = each.key
    }
  }
  dynamic "user" {
    for_each = toset(var.admins)
    content {
      permission = "admin"
      username   = each.key
    }
  }
}
