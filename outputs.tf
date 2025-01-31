
output "map1" {
  description   = "A 0- or 1-item list of created certificate_map 1 resource"
  value         = google_certificate_manager_certificate_map.m1
}

output "map2" {
  description   = "A 0- or 1-item list of created certificate_map 2 resource"
  value         = google_certificate_manager_certificate_map.m2
}

output "keys" {
  description   = "The list of all keys, some used in each of the below maps"
  value         = local.fqs
}

output "dns-auths" {
  description   = "A map of DNS authorizations created"
  value         = google_certificate_manager_dns_authorization.a
}

output "dns-records" {
  description   = "A map of DNS records created to authorize certificates"
  value         = google_dns_record_set.d
}

output "dns-certs" {
  description   = "A map of DNS-authorized certificates created"
  value         = google_certificate_manager_certificate.dns
}

output "lb-certs" {
  description   = "A map of LB-authorized certificates created"
  value         = google_certificate_manager_certificate.lb
}

output "primary1" {
  description   = "A 0- or 1-entry map with the PRIMARY map 1 entry"
  value         = merge(
    google_certificate_manager_certificate_map_entry.dns1p,
    google_certificate_manager_certificate_map_entry.lb1p,
    google_certificate_manager_certificate_map_entry.ext1p,
  )
}

output "primary2" {
  description   = "A 0- or 1-entry map with the PRIMARY map 2 entry"
  value         = merge(
    google_certificate_manager_certificate_map_entry.dns2p,
    google_certificate_manager_certificate_map_entry.lb2p,
    google_certificate_manager_certificate_map_entry.ext2p,
  )
}

output "others1" {
  description   = "A map of certificate map 1 entries for non-PRIMARY certs"
  value         = merge(
    google_certificate_manager_certificate_map_entry.dns1,
    google_certificate_manager_certificate_map_entry.lb1,
    google_certificate_manager_certificate_map_entry.ext1,
  )
}

output "others2" {
  description   = "A map of certificate map 2 entries for non-PRIMARY certs"
  value         = merge(
    google_certificate_manager_certificate_map_entry.dns2,
    google_certificate_manager_certificate_map_entry.lb2,
    google_certificate_manager_certificate_map_entry.ext2,
  )
}

