variable "name" {
  type        = string
  description = "Name of the load balancer"
}
variable "url_map_id" {
  type        = string
  description = "Id of the https url map"
}
variable "https_redirect" {
  type        = bool
  default     = false
  description = "Whether to create an HTTP to HTTPS redirect. Note this requires an additional forwarding rule so it is common to only have this for your production loadbalancer."
}

resource "google_compute_global_address" "main" {
  name = var.name
}

resource "google_certificate_manager_certificate_map" "https" {
  name = var.name
}

resource "google_compute_target_https_proxy" "https" {
  name            = var.name
  url_map         = var.url_map_id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.https.id}"
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = var.name
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https.id
  ip_address            = google_compute_global_address.main.id
}

resource "google_compute_url_map" "http" {
  count = var.https_redirect ? 1 : 0
  name  = "${var.name}-http-redirect"
  default_url_redirect {
    strip_query    = false
    https_redirect = true
  }
}

resource "google_compute_target_http_proxy" "http" {
  count   = var.https_redirect ? 1 : 0
  name    = "${var.name}-http-redirect"
  url_map = google_compute_url_map.http[0].id
}

resource "google_compute_global_forwarding_rule" "http" {
  count                 = var.https_redirect ? 1 : 0
  name                  = "${var.name}-http-redirect"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http[0].id
  ip_address            = google_compute_global_address.main.id
}
