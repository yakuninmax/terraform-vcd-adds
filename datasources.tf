# Install Powershell DSC modules
data "template_file" "configure-dsc" {
  template = file("${path.module}/cmd/configure_dsc.cmd")
}

# Install ADDS
data "template_file" "install-adds" {
  template = file("${path.module}/cmd/run_dsc.cmd")

  vars = {
    deploy_mode              = "'${var.deploy_mode}'"
    new_dc_name              = "'${join(",", var.new_dc_name)}'"
    dc_internal_ip           = "'${join(",", var.dc_internal_ip)}'"
    new_domain_name          = "'${var.new_domain_name}'"
    dsrm_password            = "'${var.dsrm_password}'"
    domain_admin_password    = "'${var.domain_admin_password}'"
    existing_domain_name     = "'${var.existing_domain_name}'"
    existing_domain_user     = "'${var.existing_domain_user}'"
    existing_domain_password = "'${var.existing_domain_password}'"
    existing_domain_dns      = "'${join(",", var.existing_domain_dns)}'"
  }
}

# Configure DNS settings on first DC
data "template_file" "first-dc-dns" {  
  count = var.deploy_mode != "NewDC" ? length(var.new_dc_name) == 1 ? 0 : 1 : 0
  template = file("${path.module}/cmd/configure_dns.cmd")

  vars = {
    dns_servers = "127.0.0.1,${var.dc_internal_ip[1]}"
  }
}

# Configure DNS settings on secondary DCs
data "template_file" "secondary-dc-dns" {  
  count = var.deploy_mode != "NewDC" ? length(var.new_dc_name) == 1 ? 0 : 1 : 0
  template = file("${path.module}/cmd/configure_dns.cmd")

  vars = {
    dns_servers = "127.0.0.1,${var.dc_internal_ip[0]}"
  }
}

# Configure DNS settings on new DCs in new domain
data "template_file" "new-dc-dns" {  
  count = var.deploy_mode == "NewDC" ? 1 : 0
  template = file("${path.module}/cmd/configure_dns.cmd")

  vars = {
    dns_servers = "127.0.0.1,${var.existing_domain_dns[0]}"
  }
}

# Cleanup
data "template_file" "cleanup" {
  template = file("${path.module}/cmd/cleanup.cmd")
}