variable "name" {
  default     = null
  description = "The name of the accelerator. If null, a random UUID is used."
}

variable "ip_address_type" {
  default     = null
  description = "IP address type for the accelerator's static anycast IPs ('IPV4' or 'DUAL_STACK'). If null, AWS's own default applies."
}

variable "ip_addresses" {
  default     = null
  description = "BYOIP addresses to use for the accelerator's static IPs, from an address pool already provisioned in this account. If null, AWS assigns new anycast IPs automatically."
}

variable "enabled" {
  default     = null
  description = "Whether the accelerator is enabled and routing traffic. If null, AWS's own default applies."
}

variable "flow_logs_enabled" {
  default     = null
  description = "Whether flow logs are published for the accelerator. Requires flow_logs_s3_bucket. If null, flow logging is left unconfigured."
}

variable "flow_logs_s3_bucket" {
  default     = null
  description = "The name of the S3 bucket flow logs are published to, when flow_logs_enabled is true."
}

variable "flow_logs_s3_prefix" {
  default     = null
  description = "Prefix for flow log object keys in flow_logs_s3_bucket."
}

variable "listeners" {
  default     = {}
  description = <<-EOT
    Listeners to create, keyed by an arbitrary name (e.g. "https"). Each entry needs
    protocol ('TCP' or 'UDP') and port_ranges (a list of {from_port, to_port} — a single
    port is from_port == to_port). client_affinity ('NONE' or 'SOURCE_IP') defaults to
    AWS's own 'NONE' when left null.

    endpoint_groups, keyed by AWS region name (e.g. "us-east-1"), are the regional
    targets this listener's traffic is distributed across — this is the mechanism that
    actually makes an accelerator global: one accelerator, one listener, one endpoint
    group per region. Each group's endpoint_configurations list the actual targets in
    that region and their relative weight: endpoint_id for a same-account ALB, NLB, EC2
    instance, or EIP (its ARN for ALB/NLB, its ID for an instance or EIP); attachment_arn
    only for a cross-account endpoint, referencing a separate
    aws_globalaccelerator_cross_account_attachment resource this module does not create.
    traffic_dial_percentage lets a region be partially or fully drained of traffic
    without removing it.
  EOT
  type = map(object({
    protocol        = string
    client_affinity = optional(string)
    port_ranges = list(object({
      from_port = number
      to_port   = number
    }))
    endpoint_groups = optional(map(object({
      health_check_interval_seconds = optional(number)
      health_check_path             = optional(string)
      health_check_port             = optional(number)
      health_check_protocol         = optional(string)
      threshold_count               = optional(number)
      traffic_dial_percentage       = optional(number)
      endpoint_configurations = optional(list(object({
        endpoint_id                    = optional(string)
        attachment_arn                 = optional(string)
        weight                         = optional(number)
        client_ip_preservation_enabled = optional(bool)
      })), [])
      port_overrides = optional(list(object({
        listener_port = number
        endpoint_port = number
      })), [])
    })), {})
  }))

  validation {
    condition     = alltrue([for k, l in var.listeners : contains(["TCP", "UDP"], l.protocol)])
    error_message = "Each listener's protocol must be 'TCP' or 'UDP'."
  }

  validation {
    condition = alltrue([
      for k, l in var.listeners : l.client_affinity == null || contains(["NONE", "SOURCE_IP"], l.client_affinity)
    ])
    error_message = "Each listener's client_affinity must be 'NONE' or 'SOURCE_IP' when set."
  }

  validation {
    condition = alltrue(flatten([
      for lk, l in var.listeners : [
        for rk, g in l.endpoint_groups : (
          g.traffic_dial_percentage == null || (g.traffic_dial_percentage >= 0 && g.traffic_dial_percentage <= 100)
        )
      ]
    ]))
    error_message = "Each endpoint group's traffic_dial_percentage must be between 0 and 100 when set."
  }
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the accelerator."
}
