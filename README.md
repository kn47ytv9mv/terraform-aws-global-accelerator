# terraform-aws-global-accelerator

Terraform module for an AWS Global Accelerator — static anycast IPs that
route internet traffic onto AWS's private backbone to the nearest
healthy regional endpoint.

## Cost

An accelerator bills hourly for as long as it exists, plus a data
transfer premium over standard rates, plus a charge per new client
TCP/UDP connection — a real, ongoing cost, not a free complement to
Route53 latency routing (see [Design](#design)). See AWS's
[Global Accelerator pricing](https://aws.amazon.com/global-accelerator/pricing/)
page for current rates.

## Design

One accelerator, one or more listeners (`listeners`, e.g. one for HTTPS
traffic), each with one endpoint group per region it should serve
(`endpoint_groups`, keyed by AWS region name) — this is the layer that
actually makes an accelerator global. Every endpoint group's
`traffic_dial_percentage` can drain a region's share of traffic down to
zero without removing it from the configuration, and health checks
(`health_check_*` on each group) automatically stop routing to a region
that fails them.

This is a different mechanism from Route53 latency-based routing in
[`terraform-aws-route53-record`](https://github.com/kn47ytv9mv/terraform-aws-route53-record) —
DNS-based routing sends a client to a region's own IP address once, at
resolution time, over the public internet from there on; an accelerator
gives a client one fixed anycast IP that AWS's own network routes to the
nearest healthy region on every packet. The two are not mutually
exclusive, but an accelerator is the higher-cost, higher-connectivity
option — reach for Route53 routing policies first, and an accelerator
once actual latency or packet loss over the public internet is a
measured problem worth paying to solve directly.

## Usage

```hcl
module "global_accelerator" {
  source = "kn47ytv9mv/global-accelerator/aws"

  listeners = {
    https = {
      protocol    = "TCP"
      port_ranges = [{ from_port = 443, to_port = 443 }]

      endpoint_groups = {
        "us-east-1" = {
          endpoint_configurations = [{
            endpoint_id = module.alb_us_east_1.arn
            weight      = 100
          }]
        }
        "eu-west-1" = {
          endpoint_configurations = [{
            endpoint_id = module.alb_eu_west_1.arn
            weight      = 100
          }]
        }
      }
    }
  }
}
```

`endpoint_id` takes the ALB's own ARN directly — `attachment_arn` is a
different field, only for a cross-account endpoint via a separate
`aws_globalaccelerator_cross_account_attachment` this module does not
create.

Or directly from this repository, draining a region to zero traffic
without removing it:

```hcl
module "global_accelerator" {
  source = "github.com/kn47ytv9mv/terraform-aws-global-accelerator"

  listeners = {
    https = {
      protocol    = "TCP"
      port_ranges = [{ from_port = 443, to_port = 443 }]

      endpoint_groups = {
        "us-east-1" = {
          traffic_dial_percentage = 100
          endpoint_configurations = [{
            endpoint_id = module.alb_us_east_1.arn
          }]
        }
        "eu-west-1" = {
          traffic_dial_percentage = 0
          endpoint_configurations = [{
            endpoint_id = module.alb_eu_west_1.arn
          }]
        }
      }
    }
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | The name of the accelerator. If null, a random UUID is used. | `null` | no |
| ip_address_type | IP address type for the accelerator's static anycast IPs (`'IPV4'` or `'DUAL_STACK'`). If null, AWS's own default applies. | `null` | no |
| ip_addresses | BYOIP addresses to use for the accelerator's static IPs, from an address pool already provisioned in this account. If null, AWS assigns new anycast IPs automatically. | `null` | no |
| enabled | Whether the accelerator is enabled and routing traffic. If null, AWS's own default applies. | `null` | no |
| flow_logs_enabled | Whether flow logs are published for the accelerator. Requires `flow_logs_s3_bucket`. If null, flow logging is left unconfigured. | `null` | no |
| flow_logs_s3_bucket | The name of the S3 bucket flow logs are published to, when `flow_logs_enabled` is true. | `null` | no |
| flow_logs_s3_prefix | Prefix for flow log object keys in `flow_logs_s3_bucket`. | `null` | no |
| listeners | Listeners to create, keyed by an arbitrary name. Each endpoint's `endpoint_id` takes an ALB/NLB ARN or EC2 instance/EIP ID directly; `attachment_arn` is only for a cross-account endpoint. See [Design](#design). | `{}` | no |
| tags | A map of tags to assign to the accelerator. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the accelerator. |
| arn | The ARN of the accelerator. |
| dns_name | DNS name of the accelerator — point a Route53 alias record here. |
| hosted_zone_id | Route53 hosted zone ID for the accelerator's `dns_name`, for an alias record's `zone_id`. |
| ip_sets | The accelerator's static anycast IP addresses, by IP family. |
| listener_ids | Map of listener name to its ID. |
| endpoint_group_ids | Map of `'<listener name>:<region>'` to its endpoint group ID. |
| name | The name of the accelerator. |

## License

MIT — see [LICENSE.md](LICENSE.md).
