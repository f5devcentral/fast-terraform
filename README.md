# F5 BIG-IP Terraform Provider
# F5 BIG-IP FAST resources


## Introduction

The objective of this templates are to demonstrate how F5 BIG-IP FAST can be used to manage, deploy, and log changes in applications using Terraform as a resource manager through their API.

For users who have access to UDF, you will find the templates in the following link:

[UDF](https://udf.f5.com) All the files needed and scenarios mentioned are located in $HOME/terraform.

# F5 BIG-IP Application Services Templates

F5 BIG-IP Application Services Templates (FAST) are an easy and effective way to deploy applications on the F5 BIG-IP system using F5 BIG-IP AS3.

The F5 BIG-IP FAST Extension provides a toolset for templating and managing F5 BIG-IP AS3 Applications on F5 BIG-IP.

# Documentation

For more information about F5 BIG-IP FAST, including installation and usage information, see the F5 BIG-IP FAST [Documentation](https://clouddocs.f5.com/products/extensions/f5-appsvcs-templates/latest/)

#F5 BIG-IP FAST github

https://github.com/F5Networks/f5-appsvcs-templates

# Terraform

HashiCorp Terraform is an infrastructure as code tool that lets you define both cloud and on-prem resources in human-readable configuration files that you can version, reuse, and share. You can then use a consistent workflow to provision and manage all ofyour infrastructure throughout its lifecycle. Terraform can manage low-level componets like compute, storage, and netwoking resources, as well as high-level componets like DNS and SaaS features. (https://www.terraform.io)

NOTE: 
All the templates are provided as examples.

# Warning about configuration synchronisation issue

Beginning with BIG-IP FAST version 1.10, a checkbox has been added to the Settings tab to Disable AS3 Declaration Cache. By disabling BIG-IP AS3 caching, BIG-IP FAST uses the most up-to-date declarations from AS3 which can affect the UI updating when config-sync is modifying an AS3 declaration. Be aware that by checking Disable AS3 Declaration Cache, BIG-IP FAST will check more frequently for application state which may slow performance, but solves the config-sync issue.

https://clouddocs.f5.com/products/extensions/f5-appsvcs-templates/latest/userguide/troubleshooting.html#big-ip-fast-ui-not-updating-after-config-sync

# Warning about provisionning

You should setup management provisioning to large and also follow the best practices from AS3 regarding restjavad

https://clouddocs.f5.com/products/extensions/f5-appsvcs-extension/latest/userguide/best-practices.html?highlight=resource%20provisioning

## Use-cases

### Scenario #1: Creating a UDP application

The goal of this template is to deploy a new UDP application on F5 BIG-IP using Terraform as the orchestrator.

### Scenario #2: Creating a TCP application

The goal of this template is to deploy a new TCP application on F5 BIG-IP using Terraform as the orchestrator.

### Scenario #3: Creating a HTTP application

The goal of this template is to deploy a new HTTP application on F5 BIG-IP using Terraform as the orchestrator.

### Scenario #4: Creating a HTTPS application

The goal of this template is to deploy a new HTTPS application on F5 BIG-IP using Terraform as the orchestrator.

### Scenario #5: Creating a HTTP application using pool and snat pool alreday created before

The goal of this template is to deploy a new HTTP application on F5 BIG-IP using a pool and a snat pool that have already been created

### Scenario #6: Creating a HTTPS application with F5 BIG-IP AWAF policy

The goal of this template is to deploy a new HTTPS application with Web Application Firewall policy on BIG-IP using Terraform as the orchestrator. Web application firewall policy and pool will be applied based on hostname or uri path.

### Scenario #7: Applying Canary deployment strategy for HTTPS application with Web Application Firewall policy

The goal of this template is to deploy a new HTTPS application using canary deployment strategy with Web Application Firewall policy on BIG-IP using Terraform as the orchestrator. Canary strategy will be based on HTTP header.
