resource "random_uuid" "resource" {}

resource "aws_globalaccelerator_accelerator" "resource" {
  name            = coalesce(var.name, random_uuid.resource.id)
  ip_address_type = var.ip_address_type
  ip_addresses    = var.ip_addresses
  enabled         = var.enabled

  dynamic "attributes" {
    for_each = var.flow_logs_enabled[*]

    content {
      flow_logs_enabled   = attributes.value
      flow_logs_s3_bucket = var.flow_logs_s3_bucket
      flow_logs_s3_prefix = var.flow_logs_s3_prefix
    }
  }

  tags = merge(var.tags, { name = "accelerator" })
}

resource "aws_globalaccelerator_listener" "resource" {
  for_each = var.listeners

  accelerator_arn = aws_globalaccelerator_accelerator.resource.id
  protocol        = each.value.protocol
  client_affinity = each.value.client_affinity

  dynamic "port_range" {
    for_each = each.value.port_ranges

    content {
      from_port = port_range.value.from_port
      to_port   = port_range.value.to_port
    }
  }
}

resource "aws_globalaccelerator_endpoint_group" "resource" {
  for_each = local.endpoint_groups

  listener_arn          = aws_globalaccelerator_listener.resource[each.value.listener_key].id
  endpoint_group_region = each.value.region

  health_check_interval_seconds = each.value.health_check_interval_seconds
  health_check_path             = each.value.health_check_path
  health_check_port             = each.value.health_check_port
  health_check_protocol         = each.value.health_check_protocol
  threshold_count               = each.value.threshold_count
  traffic_dial_percentage       = each.value.traffic_dial_percentage

  dynamic "endpoint_configuration" {
    for_each = each.value.endpoint_configurations

    content {
      endpoint_id                    = endpoint_configuration.value.endpoint_id
      attachment_arn                 = endpoint_configuration.value.attachment_arn
      weight                         = endpoint_configuration.value.weight
      client_ip_preservation_enabled = endpoint_configuration.value.client_ip_preservation_enabled
    }
  }

  dynamic "port_override" {
    for_each = each.value.port_overrides

    content {
      listener_port = port_override.value.listener_port
      endpoint_port = port_override.value.endpoint_port
    }
  }
}

locals {
  endpoint_groups = merge([
    for listener_key, listener in var.listeners : {
      for region, group in listener.endpoint_groups :
      "${listener_key}:${region}" => merge(group, {
        listener_key = listener_key
        region       = region
      })
    }
  ]...)
}

output "id" {
  description = "The ID of the accelerator."
  value       = aws_globalaccelerator_accelerator.resource.id
}

output "name" {
  description = "The name of the accelerator."
  value       = aws_globalaccelerator_accelerator.resource.name
}

output "arn" {
  description = "The ARN of the accelerator."
  value       = aws_globalaccelerator_accelerator.resource.arn
}

output "dns_name" {
  description = "DNS name of the accelerator — point a Route53 alias record here."
  value       = aws_globalaccelerator_accelerator.resource.dns_name
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID for the accelerator's dns_name, for an alias record's zone_id."
  value       = aws_globalaccelerator_accelerator.resource.hosted_zone_id
}

output "ip_sets" {
  description = "The accelerator's static anycast IP addresses, by IP family."
  value       = aws_globalaccelerator_accelerator.resource.ip_sets
}

output "listener_ids" {
  description = "Map of listener name to its ID."
  value       = { for k, l in aws_globalaccelerator_listener.resource : k => l.id }
}

output "endpoint_group_ids" {
  description = "Map of '<listener name>:<region>' to its endpoint group ID."
  value       = { for k, g in aws_globalaccelerator_endpoint_group.resource : k => g.id }
}
