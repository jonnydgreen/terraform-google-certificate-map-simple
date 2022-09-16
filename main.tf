
terraform {
  required_version = ">= 0.13"
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = ">= 4.30"
    }
  }
}

# So we can look up the project ID:
data "google_client_config" "default" {
}

locals {
  # Try to give a hint what failed if local.project ends up empty:
  project = "" != var.project ? var.project : [
    for p in [ data.google_client_config.default.project ] :
    try( "" != p, false ) ? p
    : "google_client_config.default does not define '.project'" ][0]

  # Parse var.dns-zone-ref to get a project ID and a managed zone title:
  dns-parts = split( "/", var.dns-zone-ref )
  zone-proj = ( 2 == length(local.dns-parts)
    ? local.dns-parts[0] : local.project )
  # Only use local.dns-data-title in 'data "google_dns_managed_zone"' block:
  dns-data-title = (
    2 == length(local.dns-parts) ? local.dns-parts[1] :
    1 == length(local.dns-parts) ? local.dns-parts[0] :
    "For dns-zone-ref, resource ID is not supported (${var.dns-zone-ref})" )
}

# Look up managed DNS zone created elsewhere:
data "google_dns_managed_zone" "z" {
  name      = local.dns-data-title
  project   = local.zone-proj
}

locals {
  # Version of managed zone title that gives hint if no such zone found:
  zone-title = ( var.dns-zone-ref == "" ? ""
    : [ for name in [ data.google_dns_managed_zone.z.name ] :
        try( 0 < length(name), false ) ? name
        : "DNS Zone ${local.zone-proj}/${local.dns-data-title} not found" ][0] )
  zone-domain = ( var.dns-zone-ref == "" ? ""
    : trimsuffix(".${data.google_dns_managed_zone.z.dns_name}", ".") )

  # For var.hostnames = [ "api", "my-product.example.com" ],
  #     local.fqdns["api"]                      = "api.my-team.com"
  #     local.fqdns["my-product.my-team.com"]   = "my-product.my-team.com"
  fqdns = { for h in var.hostnames : h => (
    1 < length(split(".",h)) ? h : "${h}${local.zone-domain}" )
    if length(split("/",h)) < 2 }
}

resource "google_certificate_manager_dns_authorization" "a" {
  for_each      = local.fqdns
  project       = local.project
  name          = lower(replace( "${var.name-prefix}${each.key}", ".", "-" ))
  description   = var.description
  domain        = each.value
  labels        = var.labels
}

locals {
  dns-auth  = google_certificate_manager_dns_authorization.a
  auth-rec  = { for h, a in local.dns-auth : h => a.dns_resource_record.0 }
}

resource "google_dns_record_set" "d" {
  for_each      = local.fqdns
  project       = local.zone-proj
  managed_zone  = local.zone-title
  name          = local.auth-rec[each.key].name
  type          = local.auth-rec[each.key].type
  ttl           = var.dns-ttl-secs
  rrdatas       = [ local.auth-rec[each.key].data ]
}

resource "google_certificate_manager_certificate" "c" {
  for_each      = local.fqdns
  name          = lower(replace( "${var.name-prefix}${each.key}", ".", "-" ))
  description   = var.description
  labels        = var.labels
  managed {
    domains             = [ local.dns-auth[each.key].domain ]
    dns_authorizations  = [ local.dns-auth[each.key].id ]
  }
}

resource "google_certificate_manager_certificate_map" "m" {
  count         = var.map-name == "" ? 0 : 1
  name          = var.map-name
  description   = var.description
  project       = local.project
  labels        = merge( var.labels, var.map-labels )
}

locals {
  keys = [ for h in var.hostnames : split("|",h)[0] ]
  new-certs = google_certificate_manager_certificate.c
  certs = { for h in var.hostnames : split("|",h)[0] =>
    1 < length(split("|",h)) ? split("|",h)[1] : local.new-certs[h].id }

  primary-name = split( "|", var.hostnames[0] )[0]
  primary = ( var.map-name == "" ? {}
    : { (local.primary-name) = local.certs[local.primary-name] } )
  others = ( var.map-name == "" || length(var.hostnames) < 2 ? {}
    : { for h, id in local.certs : h => id if h != local.primary-name } )
}

resource "google_certificate_manager_certificate_map_entry" "primary" {
  for_each      = local.primary
  map           = google_certificate_manager_certificate_map.m[0].name
  name          = lower(replace( each.key, ".", "-" ))
  description   = var.description
  certificates  = [ each.value ]
  matcher       = "PRIMARY"
  labels        = var.labels
}

resource "google_certificate_manager_certificate_map_entry" "others" {
  for_each      = local.others
  map           = google_certificate_manager_certificate_map.m[0].name
  name          = lower(replace( each.key, ".", "-" ))
  description   = var.description
  certificates  = [ each.value ]
  hostname      = can(local.fqdns[each.key]) ? local.fqdns[each.key] : each.key
  labels        = var.labels
}
