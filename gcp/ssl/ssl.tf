variable "domain" {
  type        = string
  description = "The domain to create an ssl certificate for."
}
variable "maps" {
  type        = list(string)
  description = "The ids of the certificate maps to add certificate map entries to. Note that the provider's project must be the same as the certificate map's project."
}
variable "dns_zone" {
  type        = string
  description = "The DNS zone to create the DNS record in. If not provided, the DNS record will not be created automatically."
  default     = null
}
variable "dns_zone_project" {
  type        = string
  description = "The project where the DNS zone is located. If empty, the provider's project will be used."
  default     = null
}

resource "google_certificate_manager_dns_authorization" "main" {
  name     = replace(var.domain, ".", "-")
  location = "global"
  domain   = var.domain
}
output "dns_auth" {
  value = google_certificate_manager_dns_authorization.main.dns_resource_record
}

resource "google_dns_record_set" "main" {
  count        = var.dns_zone != null ? 1 : 0
  project      = var.dns_zone_project
  name         = google_certificate_manager_dns_authorization.main.dns_resource_record.0.name
  type         = google_certificate_manager_dns_authorization.main.dns_resource_record.0.type
  ttl          = 300
  managed_zone = var.dns_zone
  rrdatas      = [google_certificate_manager_dns_authorization.main.dns_resource_record.0.data]
}

resource "google_certificate_manager_certificate" "main" {
  name  = replace(var.domain, ".", "-")
  scope = "DEFAULT"
  managed {
    domains = [
      var.domain,
      "*.${var.domain}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.main.id,
    ]
  }
}

resource "google_certificate_manager_certificate_map_entry" "root" {
  for_each     = toset(var.maps)
  name         = replace(var.domain, ".", "-")
  map          = each.key
  certificates = [google_certificate_manager_certificate.main.id]
  hostname     = var.domain
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  for_each     = toset(var.maps)
  name         = "wildcard-${replace(var.domain, ".", "-")}"
  map          = each.key
  certificates = [google_certificate_manager_certificate.main.id]
  hostname     = "*.${var.domain}"
}
