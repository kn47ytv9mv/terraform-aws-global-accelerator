mock_provider "aws" {
  mock_resource "aws_globalaccelerator_accelerator" {
    defaults = {
      arn = "arn:aws:globalaccelerator::111111111111:accelerator/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_globalaccelerator_listener" {
    defaults = {
      arn = "arn:aws:globalaccelerator::111111111111:accelerator/00000000-0000-0000-0000-000000000000/listener/11111111"
    }
  }
}

run "listener_protocol_invalid_rejected" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol    = "SIDEWAYS"
        port_ranges = [{ from_port = 443, to_port = 443 }]
      }
    }
  }

  expect_failures = [var.listeners]
}

run "client_affinity_invalid_rejected" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol        = "TCP"
        client_affinity = "SIDEWAYS"
        port_ranges     = [{ from_port = 443, to_port = 443 }]
      }
    }
  }

  expect_failures = [var.listeners]
}

run "traffic_dial_percentage_out_of_range_rejected" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol    = "TCP"
        port_ranges = [{ from_port = 443, to_port = 443 }]
        endpoint_groups = {
          "us-east-1" = {
            traffic_dial_percentage = 150
          }
        }
      }
    }
  }

  expect_failures = [var.listeners]
}

run "name_falls_back_to_random_uuid_when_unset" {
  command = apply

  assert {
    condition     = aws_globalaccelerator_accelerator.resource.name == random_uuid.resource.id
    error_message = "name should fall back to the random UUID when var.name is left unset."
  }
}

run "listener_and_two_regional_endpoint_groups_created" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol    = "TCP"
        port_ranges = [{ from_port = 443, to_port = 443 }]
        endpoint_groups = {
          "us-east-1" = {
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/app/example/0123456789abcdef"
              weight      = 100
            }]
          }
          "eu-west-1" = {
            traffic_dial_percentage = 0
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:loadbalancer/app/example/fedcba9876543210"
            }]
          }
        }
      }
    }
  }

  assert {
    condition     = length(aws_globalaccelerator_listener.resource) == 1
    error_message = "One listener should be created per entry in listeners."
  }

  assert {
    condition     = length(aws_globalaccelerator_endpoint_group.resource) == 2
    error_message = "One endpoint group should be created per region under the listener's endpoint_groups."
  }

  assert {
    condition     = aws_globalaccelerator_endpoint_group.resource["https:us-east-1"].endpoint_group_region == "us-east-1"
    error_message = "Each endpoint group should be keyed by '<listener>:<region>' and carry its own region."
  }

  assert {
    condition     = aws_globalaccelerator_endpoint_group.resource["https:eu-west-1"].traffic_dial_percentage == 0
    error_message = "traffic_dial_percentage should pass through unchanged, allowing a region to be drained without removal."
  }
}

run "no_listeners_creates_bare_accelerator" {
  command = plan

  assert {
    condition     = length(aws_globalaccelerator_listener.resource) == 0
    error_message = "No listeners were given, so none should be created."
  }

  assert {
    condition     = length(aws_globalaccelerator_endpoint_group.resource) == 0
    error_message = "No listeners means no endpoint groups either."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol    = "TCP"
        port_ranges = [{ from_port = 443, to_port = 443 }]
        endpoint_groups = {
          "us-east-1" = {
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/app/example/0123456789abcdef"
              weight      = 100
            }]
          }
          "eu-west-1" = {
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:loadbalancer/app/example/fedcba9876543210"
              weight      = 100
            }]
          }
        }
      }
    }
  }
}

run "readme_drain_region_example" {
  command = plan

  variables {
    listeners = {
      https = {
        protocol    = "TCP"
        port_ranges = [{ from_port = 443, to_port = 443 }]
        endpoint_groups = {
          "us-east-1" = {
            traffic_dial_percentage = 100
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/app/example/0123456789abcdef"
            }]
          }
          "eu-west-1" = {
            traffic_dial_percentage = 0
            endpoint_configurations = [{
              endpoint_id = "arn:aws:elasticloadbalancing:eu-west-1:111111111111:loadbalancer/app/example/fedcba9876543210"
            }]
          }
        }
      }
    }
  }

  assert {
    condition     = aws_globalaccelerator_endpoint_group.resource["https:eu-west-1"].traffic_dial_percentage == 0
    error_message = "The README's drain example should set the eu-west-1 endpoint group's traffic_dial_percentage to 0."
  }
}
