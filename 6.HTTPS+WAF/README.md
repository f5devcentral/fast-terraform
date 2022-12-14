# Scenario #6: Creating a HTTPS application with Web Application Firewall policy

## Goals


The goal of this template is to deploy a new HTTPS application with Web Application Firewall policy on BIG-IP using Terraform as the orchestrator.
Web application firewall policy and pool will be applied based on hostname or uri path.

## Pre-requisites

**on the BIG-IP:**

 - [ ] version 16.1 minimal
 - [ ] credentials with REST API access
 
**on Terraform:**

 - [ ] use of F5 bigip provider version 1.16.0 minimal
 - [ ] use of Hashicorp version following [Link](https://clouddocs.f5.com/products/orchestration/terraform/latest/userguide/overview.html#releases-and-versioning)



## Create HTTPS application

Create 4 files:
- main.tf
- variables.tf
- inputs.auto.tfvars
- providers.tf


**variables.tf**
```terraform
variable "bigip" {}
variable "username" {}
variable "password" {}
variable "policyname" {
  type    = string
  default = ""

}
variable "partition" {
  type    = string
  default = "Common"
}
```

**inputs.tfvars**
```terraform
bigip = "10.1.1.9:443"
username = "admin"
password = "whatIsYourBigIPPassword?"
partition  = "Common"
policyname = "myApp6_ltm_policy"
```

**providers.tf**
```terraform
terraform {
  required_providers {
    bigip = {
      source = "F5Networks/bigip"
      version = ">= 1.16.0"
    }
  }
}
provider "bigip" {
  address  = var.bigip
  username = var.username
  password = var.password
}
```

**main.tf**
```terraform
resource "bigip_waf_policy" "app1" {
  provider             = bigip
  description          = "WAF Policy for App1"
  name                 = "app1"
  partition            = var.partition
  template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
  application_language = "utf-8"
  enforcement_mode     = "blocking"
  server_technologies  = ["Apache Tomcat", "MySQL", "Unix/Linux"]
}

resource "time_sleep" "wait_a" {
  create_duration = "10s"
  depends_on      = [bigip_waf_policy.app1, bigip_waf_policy.app2]
}

resource "time_sleep" "wait_b" {
  create_duration = "10s"
  depends_on      = [bigip_waf_policy.restricted]
}

resource "bigip_waf_policy" "app2" {
  provider             = bigip
  description          = "WAF Policy for App2"
  name                 = "app2"
  partition            = var.partition
  template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
  application_language = "utf-8"
  enforcement_mode     = "blocking"
  server_technologies  = ["Apache Tomcat", "MySQL", "Unix/Linux", "MongoDB"]
}

resource "bigip_waf_policy" "restricted" {
  provider             = bigip
  description          = "WAF Policy for restricted areas"
  name                 = "restricted"
  partition            = var.partition
  template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
  application_language = "utf-8"
  enforcement_mode     = "blocking"
  server_technologies  = ["Apache Tomcat", "MySQL", "Unix/Linux", "MongoDB"]
  depends_on           = [time_sleep.wait_a]
}

resource "bigip_waf_policy" "default" {
  provider             = bigip
  description          = "desfault WAF Policy"
  name                 = "default"
  partition            = var.partition
  template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
  application_language = "utf-8"
  enforcement_mode     = "blocking"
  server_technologies  = ["Apache Tomcat", "MySQL", "Unix/Linux", "MongoDB"]
  depends_on           = [time_sleep.wait_b]
}

resource "bigip_ltm_pool" "pool1" {
  provider            = bigip
  name                = "/${var.partition}/pool1"
  allow_nat           = "yes"
  allow_snat          = "yes"
  load_balancing_mode = "round-robin"
}

resource "bigip_ltm_pool_attachment" "pool1-member" {
	pool = bigip_ltm_pool.pool1.name
	node = "10.1.10.120:80"
}

resource "bigip_ltm_pool" "pool2" {
  provider            = bigip
  name                = "/${var.partition}/pool2"
  allow_nat           = "yes"
  allow_snat          = "yes"
  load_balancing_mode = "round-robin"
}

resource "bigip_ltm_pool_attachment" "pool2-member" {
        pool = bigip_ltm_pool.pool2.name
        node = "10.1.10.121:80"
}

resource "bigip_ltm_pool" "pool_restricted" {
  provider            = bigip
  name                = "/${var.partition}/pool_restricted"
  allow_nat           = "yes"
  allow_snat          = "yes"
  load_balancing_mode = "round-robin"
}

module "consolidated_vips" {
  source = "github.com/f5devcentral/fast-terraform//multiple_waf_policies?ref=v1.0.0"
  providers = {
    bigip = bigip
  }
  name      = var.policyname
  partition = var.partition
  rules = [
    {
      name      = "WWW1_App"
      hostname  = ["www1.f5demo.com", "app1.f5demo.com"]
      policy    = bigip_waf_policy.app1.name
      pool_name = bigip_ltm_pool.pool1.name
    },
    {
      name      = "WWW2_App"
      hostname  = ["www2.f5demo.com"]
      policy    = bigip_waf_policy.app2.name
      pool_name = bigip_ltm_pool.pool2.name
    },
    {
      name      = "restricted"
      path      = ["/restricted", "/admin", "/hr"]
      policy    = bigip_waf_policy.restricted.name
      pool_name = bigip_ltm_pool.pool_restricted.name
  }]
  default_policy = bigip_waf_policy.default.name
  depends_on     = [bigip_waf_policy.app1, bigip_waf_policy.app2, bigip_waf_policy.restricted, bigip_waf_policy.default]
}

resource "bigip_fast_https_app" "this" {
  application = "myApp6"
  tenant      = "scenario6"
  virtual_server {
    ip   = "10.1.10.226"
    port = 443
  }
  tls_server_profile {
    tls_cert_name = "/Common/default.crt"
    tls_key_name  = "/Common/default.key"
  }
  snat_pool_address     = ["10.1.10.50", "10.1.10.51", "10.1.10.52"]
  endpoint_ltm_policy   = ["${module.consolidated_vips.ltmPolicyName}"]
  security_log_profiles = ["/Common/Log all requests"]
  depends_on            = [bigip_waf_policy.app1, bigip_waf_policy.app2, bigip_waf_policy.restricted, bigip_waf_policy.default, module.consolidated_vips.ltmPolicyName]
}
```

Now, run the following commands, so we can:
1. Initialize the terraform project
2. Plan the changes
3. Apply the changes


```console
$ terraform init -upgrade
Upgrading modules...
Downloading git::https://github.com/fchmainy/waf_modules.git?ref=v1.0.8 for consolidated_vips...
- consolidated_vips in .terraform/modules/consolidated_vips/multiple_waf_policies

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/time...
- Finding f5networks/bigip versions matching ">= 1.16.0"...
- Using previously-installed hashicorp/time v0.9.1
- Using previously-installed f5networks/bigip v1.16.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.


$ terraform plan -out scenario6

Terraform used the selected providers to generate the following execution plan. Resource actions are
indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # bigip_fast_https_app.this will be created
  + resource "bigip_fast_https_app" "this" {
      + application           = "myApp6"
      + endpoint_ltm_policy   = [
          + "/Common/myApp6_ltm_policy",
        ]
      + fast_https_json       = (known after apply)
      + id                    = (known after apply)
      + load_balancing_mode   = "least-connections-member"
      + security_log_profiles = [
          + "/Common/Log all requests",
        ]
      + snat_pool_address     = [
          + "10.1.10.50",
          + "10.1.10.51",
          + "10.1.10.52",
        ]
      + tenant                = "scenario6"

      + tls_server_profile {
          + tls_cert_name = "/Common/default.crt"
          + tls_key_name  = "/Common/default.key"
        }

      + virtual_server {
          + ip   = "10.1.10.226"
          + port = 443
        }
    }

  # bigip_ltm_pool.pool1 will be created
  + resource "bigip_ltm_pool" "pool1" {
      + allow_nat              = "yes"
      + allow_snat             = "yes"
      + id                     = (known after apply)
      + load_balancing_mode    = "round-robin"
      + minimum_active_members = (known after apply)
      + monitors               = (known after apply)
      + name                   = "/Common/pool1"
      + reselect_tries         = (known after apply)
      + service_down_action    = (known after apply)
      + slow_ramp_time         = (known after apply)
    }

  # bigip_ltm_pool.pool2 will be created
  + resource "bigip_ltm_pool" "pool2" {
      + allow_nat              = "yes"
      + allow_snat             = "yes"
      + id                     = (known after apply)
      + load_balancing_mode    = "round-robin"
      + minimum_active_members = (known after apply)
      + monitors               = (known after apply)
      + name                   = "/Common/pool2"
      + reselect_tries         = (known after apply)
      + service_down_action    = (known after apply)
      + slow_ramp_time         = (known after apply)
    }

  # bigip_ltm_pool.pool_restricted will be created
  + resource "bigip_ltm_pool" "pool_restricted" {
      + allow_nat              = "yes"
      + allow_snat             = "yes"
      + id                     = (known after apply)
      + load_balancing_mode    = "round-robin"
      + minimum_active_members = (known after apply)
      + monitors               = (known after apply)
      + name                   = "/Common/pool_restricted"
      + reselect_tries         = (known after apply)
      + service_down_action    = (known after apply)
      + slow_ramp_time         = (known after apply)
    }

  # bigip_ltm_pool_attachment.pool1-member will be created
  + resource "bigip_ltm_pool_attachment" "pool1-member" {
      + connection_limit      = (known after apply)
      + connection_rate_limit = (known after apply)
      + dynamic_ratio         = (known after apply)
      + id                    = (known after apply)
      + node                  = "10.1.10.120:80"
      + pool                  = "/Common/pool1"
      + priority_group        = (known after apply)
      + ratio                 = (known after apply)
    }

  # bigip_ltm_pool_attachment.pool2-member will be created
  + resource "bigip_ltm_pool_attachment" "pool2-member" {
      + connection_limit      = (known after apply)
      + connection_rate_limit = (known after apply)
      + dynamic_ratio         = (known after apply)
      + id                    = (known after apply)
      + node                  = "10.1.10.121:80"
      + pool                  = "/Common/pool2"
      + priority_group        = (known after apply)
      + ratio                 = (known after apply)
    }

  # bigip_waf_policy.app1 will be created
  + resource "bigip_waf_policy" "app1" {
      + application_language = "utf-8"
      + case_insensitive     = false
      + description          = "WAF Policy for App1"
      + enable_passivemode   = false
      + enforcement_mode     = "blocking"
      + id                   = (known after apply)
      + name                 = "app1"
      + partition            = "Common"
      + policy_export_json   = (known after apply)
      + policy_id            = (known after apply)
      + server_technologies  = [
          + "Apache Tomcat",
          + "MySQL",
          + "Unix/Linux",
        ]
      + template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
      + type                 = "security"
    }

  # bigip_waf_policy.app2 will be created
  + resource "bigip_waf_policy" "app2" {
      + application_language = "utf-8"
      + case_insensitive     = false
      + description          = "WAF Policy for App2"
      + enable_passivemode   = false
      + enforcement_mode     = "blocking"
      + id                   = (known after apply)
      + name                 = "app2"
      + partition            = "Common"
      + policy_export_json   = (known after apply)
      + policy_id            = (known after apply)
      + server_technologies  = [
          + "Apache Tomcat",
          + "MySQL",
          + "Unix/Linux",
          + "MongoDB",
        ]
      + template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
      + type                 = "security"
    }

  # bigip_waf_policy.default will be created
  + resource "bigip_waf_policy" "default" {
      + application_language = "utf-8"
      + case_insensitive     = false
      + description          = "desfault WAF Policy"
      + enable_passivemode   = false
      + enforcement_mode     = "blocking"
      + id                   = (known after apply)
      + name                 = "default"
      + partition            = "Common"
      + policy_export_json   = (known after apply)
      + policy_id            = (known after apply)
      + server_technologies  = [
          + "Apache Tomcat",
          + "MySQL",
          + "Unix/Linux",
          + "MongoDB",
        ]
      + template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
      + type                 = "security"
    }

  # bigip_waf_policy.restricted will be created
  + resource "bigip_waf_policy" "restricted" {
      + application_language = "utf-8"
      + case_insensitive     = false
      + description          = "WAF Policy for restricted areas"
      + enable_passivemode   = false
      + enforcement_mode     = "blocking"
      + id                   = (known after apply)
      + name                 = "restricted"
      + partition            = "Common"
      + policy_export_json   = (known after apply)
      + policy_id            = (known after apply)
      + server_technologies  = [
          + "Apache Tomcat",
          + "MySQL",
          + "Unix/Linux",
          + "MongoDB",
        ]
      + template_name        = "POLICY_TEMPLATE_RAPID_DEPLOYMENT"
      + type                 = "security"
    }

  # time_sleep.wait_a will be created
  + resource "time_sleep" "wait_a" {
      + create_duration = "10s"
      + id              = (known after apply)
    }

  # time_sleep.wait_b will be created
  + resource "time_sleep" "wait_b" {
      + create_duration = "10s"
      + id              = (known after apply)
    }

  # module.consolidated_vips.bigip_ltm_policy.multiple will be created
  + resource "bigip_ltm_policy" "multiple" {
      + controls = [
          + "asm",
          + "forwarding",
        ]
      + id       = (known after apply)
      + name     = "/Common/myApp6_ltm_policy"
      + requires = [
          + "http",
        ]
      + strategy = "first-match"

      + rule {
          + name = "WWW1_App"

          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = (known after apply)
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = (known after apply)
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = true
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = (known after apply)
              + pool                 = "/Common/pool1"
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = true
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = "automap"
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }
          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = true
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = true
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = false
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = "/Common/app1"
              + pool                 = (known after apply)
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = (known after apply)
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = (known after apply)
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }

          + condition {
              + address                 = (known after apply)
              + all                     = (known after apply)
              + app_service             = (known after apply)
              + browser_type            = (known after apply)
              + browser_version         = (known after apply)
              + case_insensitive        = true
              + case_sensitive          = (known after apply)
              + cipher                  = (known after apply)
              + cipher_bits             = (known after apply)
              + client_accepted         = (known after apply)
              + client_ssl              = (known after apply)
              + code                    = (known after apply)
              + common_name             = (known after apply)
              + contains                = true
              + continent               = (known after apply)
              + country_code            = (known after apply)
              + country_name            = (known after apply)
              + cpu_usage               = (known after apply)
              + device_make             = (known after apply)
              + device_model            = (known after apply)
              + domain                  = (known after apply)
              + ends_with               = (known after apply)
              + equals                  = (known after apply)
              + exists                  = (known after apply)
              + expiry                  = (known after apply)
              + extension               = (known after apply)
              + external                = true
              + geoip                   = (known after apply)
              + greater                 = (known after apply)
              + greater_or_equal        = (known after apply)
              + host                    = true
              + http_basic_auth         = (known after apply)
              + http_cookie             = (known after apply)
              + http_header             = (known after apply)
              + http_host               = true
              + http_method             = (known after apply)
              + http_referer            = (known after apply)
              + http_set_cookie         = (known after apply)
              + http_status             = (known after apply)
              + http_uri                = false
              + http_user_agent         = (known after apply)
              + http_version            = (known after apply)
              + index                   = (known after apply)
              + internal                = (known after apply)
              + isp                     = (known after apply)
              + last_15secs             = (known after apply)
              + last_1min               = (known after apply)
              + last_5mins              = (known after apply)
              + less                    = (known after apply)
              + less_or_equal           = (known after apply)
              + local                   = (known after apply)
              + major                   = (known after apply)
              + matches                 = (known after apply)
              + minor                   = (known after apply)
              + missing                 = (known after apply)
              + mss                     = (known after apply)
              + not                     = (known after apply)
              + org                     = (known after apply)
              + password                = (known after apply)
              + path                    = false
              + path_segment            = (known after apply)
              + port                    = (known after apply)
              + present                 = true
              + protocol                = (known after apply)
              + query_parameter         = (known after apply)
              + query_string            = (known after apply)
              + region_code             = (known after apply)
              + region_name             = (known after apply)
              + remote                  = true
              + request                 = true
              + response                = (known after apply)
              + route_domain            = (known after apply)
              + rtt                     = (known after apply)
              + scheme                  = (known after apply)
              + server_name             = (known after apply)
              + ssl_cert                = (known after apply)
              + ssl_client_hello        = (known after apply)
              + ssl_extension           = (known after apply)
              + ssl_server_handshake    = (known after apply)
              + ssl_server_hello        = (known after apply)
              + starts_with             = false
              + tcp                     = (known after apply)
              + text                    = (known after apply)
              + tm_name                 = (known after apply)
              + unnamed_query_parameter = (known after apply)
              + user_agent_token        = (known after apply)
              + username                = (known after apply)
              + value                   = (known after apply)
              + values                  = [
                  + "www1.f5demo.com",
                  + "app1.f5demo.com",
                ]
              + version                 = (known after apply)
              + vlan                    = (known after apply)
              + vlan_id                 = (known after apply)
            }
        }
      + rule {
          + name = "WWW2_App"

          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = (known after apply)
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = (known after apply)
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = true
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = (known after apply)
              + pool                 = "/Common/pool2"
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = true
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = "automap"
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }
          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = true
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = true
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = false
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = "/Common/app2"
              + pool                 = (known after apply)
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = (known after apply)
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = (known after apply)
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }

          + condition {
              + address                 = (known after apply)
              + all                     = (known after apply)
              + app_service             = (known after apply)
              + browser_type            = (known after apply)
              + browser_version         = (known after apply)
              + case_insensitive        = true
              + case_sensitive          = (known after apply)
              + cipher                  = (known after apply)
              + cipher_bits             = (known after apply)
              + client_accepted         = (known after apply)
              + client_ssl              = (known after apply)
              + code                    = (known after apply)
              + common_name             = (known after apply)
              + contains                = true
              + continent               = (known after apply)
              + country_code            = (known after apply)
              + country_name            = (known after apply)
              + cpu_usage               = (known after apply)
              + device_make             = (known after apply)
              + device_model            = (known after apply)
              + domain                  = (known after apply)
              + ends_with               = (known after apply)
              + equals                  = (known after apply)
              + exists                  = (known after apply)
              + expiry                  = (known after apply)
              + extension               = (known after apply)
              + external                = true
              + geoip                   = (known after apply)
              + greater                 = (known after apply)
              + greater_or_equal        = (known after apply)
              + host                    = true
              + http_basic_auth         = (known after apply)
              + http_cookie             = (known after apply)
              + http_header             = (known after apply)
              + http_host               = true
              + http_method             = (known after apply)
              + http_referer            = (known after apply)
              + http_set_cookie         = (known after apply)
              + http_status             = (known after apply)
              + http_uri                = false
              + http_user_agent         = (known after apply)
              + http_version            = (known after apply)
              + index                   = (known after apply)
              + internal                = (known after apply)
              + isp                     = (known after apply)
              + last_15secs             = (known after apply)
              + last_1min               = (known after apply)
              + last_5mins              = (known after apply)
              + less                    = (known after apply)
              + less_or_equal           = (known after apply)
              + local                   = (known after apply)
              + major                   = (known after apply)
              + matches                 = (known after apply)
              + minor                   = (known after apply)
              + missing                 = (known after apply)
              + mss                     = (known after apply)
              + not                     = (known after apply)
              + org                     = (known after apply)
              + password                = (known after apply)
              + path                    = false
              + path_segment            = (known after apply)
              + port                    = (known after apply)
              + present                 = true
              + protocol                = (known after apply)
              + query_parameter         = (known after apply)
              + query_string            = (known after apply)
              + region_code             = (known after apply)
              + region_name             = (known after apply)
              + remote                  = true
              + request                 = true
              + response                = (known after apply)
              + route_domain            = (known after apply)
              + rtt                     = (known after apply)
              + scheme                  = (known after apply)
              + server_name             = (known after apply)
              + ssl_cert                = (known after apply)
              + ssl_client_hello        = (known after apply)
              + ssl_extension           = (known after apply)
              + ssl_server_handshake    = (known after apply)
              + ssl_server_hello        = (known after apply)
              + starts_with             = false
              + tcp                     = (known after apply)
              + text                    = (known after apply)
              + tm_name                 = (known after apply)
              + unnamed_query_parameter = (known after apply)
              + user_agent_token        = (known after apply)
              + username                = (known after apply)
              + value                   = (known after apply)
              + values                  = [
                  + "www2.f5demo.com",
                ]
              + version                 = (known after apply)
              + vlan                    = (known after apply)
              + vlan_id                 = (known after apply)
            }
        }
      + rule {
          + name = "restricted"

          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = (known after apply)
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = (known after apply)
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = true
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = (known after apply)
              + pool                 = "/Common/pool_restricted"
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = true
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = "automap"
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }
          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = true
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = true
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = false
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = "/Common/restricted"
              + pool                 = (known after apply)
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = (known after apply)
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = (known after apply)
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }

          + condition {
              + address                 = (known after apply)
              + all                     = (known after apply)
              + app_service             = (known after apply)
              + browser_type            = (known after apply)
              + browser_version         = (known after apply)
              + case_insensitive        = true
              + case_sensitive          = (known after apply)
              + cipher                  = (known after apply)
              + cipher_bits             = (known after apply)
              + client_accepted         = (known after apply)
              + client_ssl              = (known after apply)
              + code                    = (known after apply)
              + common_name             = (known after apply)
              + contains                = false
              + continent               = (known after apply)
              + country_code            = (known after apply)
              + country_name            = (known after apply)
              + cpu_usage               = (known after apply)
              + device_make             = (known after apply)
              + device_model            = (known after apply)
              + domain                  = (known after apply)
              + ends_with               = (known after apply)
              + equals                  = (known after apply)
              + exists                  = (known after apply)
              + expiry                  = (known after apply)
              + extension               = (known after apply)
              + external                = true
              + geoip                   = (known after apply)
              + greater                 = (known after apply)
              + greater_or_equal        = (known after apply)
              + host                    = false
              + http_basic_auth         = (known after apply)
              + http_cookie             = (known after apply)
              + http_header             = (known after apply)
              + http_host               = false
              + http_method             = (known after apply)
              + http_referer            = (known after apply)
              + http_set_cookie         = (known after apply)
              + http_status             = (known after apply)
              + http_uri                = true
              + http_user_agent         = (known after apply)
              + http_version            = (known after apply)
              + index                   = (known after apply)
              + internal                = (known after apply)
              + isp                     = (known after apply)
              + last_15secs             = (known after apply)
              + last_1min               = (known after apply)
              + last_5mins              = (known after apply)
              + less                    = (known after apply)
              + less_or_equal           = (known after apply)
              + local                   = (known after apply)
              + major                   = (known after apply)
              + matches                 = (known after apply)
              + minor                   = (known after apply)
              + missing                 = (known after apply)
              + mss                     = (known after apply)
              + not                     = (known after apply)
              + org                     = (known after apply)
              + password                = (known after apply)
              + path                    = true
              + path_segment            = (known after apply)
              + port                    = (known after apply)
              + present                 = true
              + protocol                = (known after apply)
              + query_parameter         = (known after apply)
              + query_string            = (known after apply)
              + region_code             = (known after apply)
              + region_name             = (known after apply)
              + remote                  = true
              + request                 = true
              + response                = (known after apply)
              + route_domain            = (known after apply)
              + rtt                     = (known after apply)
              + scheme                  = (known after apply)
              + server_name             = (known after apply)
              + ssl_cert                = (known after apply)
              + ssl_client_hello        = (known after apply)
              + ssl_extension           = (known after apply)
              + ssl_server_handshake    = (known after apply)
              + ssl_server_hello        = (known after apply)
              + starts_with             = true
              + tcp                     = (known after apply)
              + text                    = (known after apply)
              + tm_name                 = (known after apply)
              + unnamed_query_parameter = (known after apply)
              + user_agent_token        = (known after apply)
              + username                = (known after apply)
              + value                   = (known after apply)
              + values                  = [
                  + "/restricted",
                  + "/admin",
                  + "/hr",
                ]
              + version                 = (known after apply)
              + vlan                    = (known after apply)
              + vlan_id                 = (known after apply)
            }
        }
      + rule {
          + name = "default"

          + action {
              + app_service          = (known after apply)
              + application          = (known after apply)
              + asm                  = true
              + avr                  = (known after apply)
              + cache                = (known after apply)
              + carp                 = (known after apply)
              + category             = (known after apply)
              + classify             = (known after apply)
              + clone_pool           = (known after apply)
              + code                 = (known after apply)
              + compress             = (known after apply)
              + connection           = false
              + content              = (known after apply)
              + cookie_hash          = (known after apply)
              + cookie_insert        = (known after apply)
              + cookie_passive       = (known after apply)
              + cookie_rewrite       = (known after apply)
              + decompress           = (known after apply)
              + defer                = (known after apply)
              + destination_address  = (known after apply)
              + disable              = (known after apply)
              + domain               = (known after apply)
              + enable               = true
              + expiry               = (known after apply)
              + expiry_secs          = (known after apply)
              + expression           = (known after apply)
              + extension            = (known after apply)
              + facility             = (known after apply)
              + forward              = false
              + from_profile         = (known after apply)
              + hash                 = (known after apply)
              + host                 = (known after apply)
              + http                 = (known after apply)
              + http_basic_auth      = (known after apply)
              + http_cookie          = (known after apply)
              + http_header          = (known after apply)
              + http_referer         = (known after apply)
              + http_reply           = (known after apply)
              + http_set_cookie      = (known after apply)
              + http_uri             = (known after apply)
              + ifile                = (known after apply)
              + insert               = (known after apply)
              + internal_virtual     = (known after apply)
              + ip_address           = (known after apply)
              + key                  = (known after apply)
              + l7dos                = (known after apply)
              + length               = (known after apply)
              + location             = (known after apply)
              + log                  = (known after apply)
              + ltm_policy           = (known after apply)
              + member               = (known after apply)
              + message              = (known after apply)
              + netmask              = (known after apply)
              + nexthop              = (known after apply)
              + node                 = (known after apply)
              + offset               = (known after apply)
              + path                 = (known after apply)
              + pem                  = (known after apply)
              + persist              = (known after apply)
              + pin                  = (known after apply)
              + policy               = "/Common/default"
              + pool                 = (known after apply)
              + port                 = (known after apply)
              + priority             = (known after apply)
              + profile              = (known after apply)
              + protocol             = (known after apply)
              + query_string         = (known after apply)
              + rateclass            = (known after apply)
              + redirect             = (known after apply)
              + remove               = (known after apply)
              + replace              = (known after apply)
              + request              = true
              + request_adapt        = (known after apply)
              + reset                = (known after apply)
              + response             = (known after apply)
              + response_adapt       = (known after apply)
              + scheme               = (known after apply)
              + script               = (known after apply)
              + select               = (known after apply)
              + server_ssl           = (known after apply)
              + set_variable         = (known after apply)
              + snat                 = (known after apply)
              + snatpool             = (known after apply)
              + source_address       = (known after apply)
              + ssl_client_hello     = (known after apply)
              + ssl_server_handshake = (known after apply)
              + ssl_server_hello     = (known after apply)
              + ssl_session_id       = (known after apply)
              + status               = (known after apply)
              + tcl                  = (known after apply)
              + tcp_nagle            = (known after apply)
              + text                 = (known after apply)
              + timeout              = (known after apply)
              + tm_name              = (known after apply)
              + uie                  = (known after apply)
              + universal            = (known after apply)
              + value                = (known after apply)
              + virtual              = (known after apply)
              + vlan                 = (known after apply)
              + vlan_id              = (known after apply)
              + wam                  = (known after apply)
              + write                = (known after apply)
            }
        }
    }

Plan: 13 to add, 0 to change, 0 to destroy.

?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

Saved the plan to: scenario6

To perform exactly these actions, run the following command to apply:
    terraform apply "scenario6"


$ terraform apply "scenario6"
bigip_ltm_pool.pool1: Creating...
bigip_waf_policy.app2: Creating...
bigip_ltm_pool.pool2: Creating...
bigip_ltm_pool.pool_restricted: Creating...
bigip_waf_policy.app1: Creating...
bigip_ltm_pool.pool_restricted: Creation complete after 1s [id=/Common/pool_restricted]
bigip_ltm_pool.pool2: Creation complete after 1s [id=/Common/pool2]
bigip_ltm_pool_attachment.pool2-member: Creating...
bigip_ltm_pool.pool1: Creation complete after 1s [id=/Common/pool1]
bigip_ltm_pool_attachment.pool1-member: Creating...
bigip_ltm_pool_attachment.pool1-member: Creation complete after 1s [id=/Common/pool1]
bigip_ltm_pool_attachment.pool2-member: Creation complete after 1s [id=/Common/pool2]
bigip_waf_policy.app2: Still creating... [10s elapsed]
bigip_waf_policy.app1: Still creating... [10s elapsed]
bigip_waf_policy.app2: Still creating... [20s elapsed]
bigip_waf_policy.app1: Still creating... [20s elapsed]
bigip_waf_policy.app1: Creation complete after 22s [id=QWEUhhZw7KHGjatuSL-B6g]
bigip_waf_policy.app2: Creation complete after 22s [id=M3pRZgaMBAnN2akf4ONvyw]
time_sleep.wait_a: Creating...
time_sleep.wait_a: Still creating... [10s elapsed]
time_sleep.wait_a: Creation complete after 10s [id=2022-11-15T14:05:00Z]
bigip_waf_policy.restricted: Creating...
bigip_waf_policy.restricted: Still creating... [10s elapsed]
bigip_waf_policy.restricted: Creation complete after 18s [id=4cO7OqgRa6EWHDv1TX7shw]
time_sleep.wait_b: Creating...
time_sleep.wait_b: Still creating... [10s elapsed]
time_sleep.wait_b: Creation complete after 10s [id=2022-11-15T14:05:27Z]
bigip_waf_policy.default: Creating...
bigip_waf_policy.default: Still creating... [10s elapsed]
bigip_waf_policy.default: Creation complete after 17s [id=IFjrv3SSrTfwCqyuijsxRg]
module.consolidated_vips.bigip_ltm_policy.multiple: Creating...
module.consolidated_vips.bigip_ltm_policy.multiple: Creation complete after 2s [id=/Common/myApp6_ltm_policy]
bigip_fast_https_app.this: Creating...
bigip_fast_https_app.this: Still creating... [10s elapsed]
bigip_fast_https_app.this: Still creating... [20s elapsed]
bigip_fast_https_app.this: Creation complete after 21s [id=myApp6]

Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

```

