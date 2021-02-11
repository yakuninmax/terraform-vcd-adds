# Install Powershell DSC modules
resource "null_resource" "configure-dsc" {
  count = length(var.new_dc_name)
    
  provisioner "remote-exec" {

  connection {
    type        = "ssh"
    user        = "Administrator"
    password    = var.local_admin_password
    host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index]
    port        = var.dc_external_ssh_port[count.index] != "" ? var.dc_external_ssh_port[count.index] : 22
    script_path = "/Windows/Temp/terraform_%RAND%.bat"
    timeout     = "15m"
  }

  inline = [data.template_file.configure-dsc.rendered]
  }
}

# Copy configuration script
resource "null_resource" "copy-script" {
  count      = length(var.new_dc_name)
  depends_on = [ null_resource.configure-dsc ]

  provisioner "file" {

    connection {
      type     = "ssh"
      user     = "Administrator"
      password = var.local_admin_password
      host     = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index]
      port     = var.dc_external_ssh_port[count.index] != "" ? var.dc_external_ssh_port[count.index] : 22
      timeout  = "15m"
    }

    source      = "${path.module}/dsc/adds_configuration.ps1"
    destination = "C:/Windows/Temp/adds_configuration.ps1"
  }
}

# Install ADDS
resource "null_resource" "install-adds" {
  count      = length(var.new_dc_name)
  depends_on = [ null_resource.copy-script ]

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = var.local_admin_password
      host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index]
      port        = var.dc_external_ssh_port[count.index] != "" ? var.dc_external_ssh_port[count.index] : 22
      script_path = "C:/Windows/Temp/terraform_%RAND%.bat"
      timeout     = "15m"
    }

  inline = [data.template_file.install-adds.rendered]
  }
}

# Wait for 2 minutes
resource "time_sleep" "wait-120-seconds" {
  depends_on      = [ null_resource.install-adds ]
  create_duration = "120s"
}

# Cleanup after installation
resource "null_resource" "cleanup" {
  count      = length(var.new_dc_name)
  depends_on = [ time_sleep.wait-120-seconds ]

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = var.deploy_mode != "NewDC" ? "Administrator" : var.existing_domain_user
      password    = var.deploy_mode != "NewDC" ? var.domain_admin_password : var.existing_domain_password
      host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index]
      port        = var.dc_external_ssh_port[count.index] != "" ? var.dc_external_ssh_port[count.index] : 22
      script_path = "C:/Windows/Temp/terraform_%RAND%.bat"
      timeout     = "15m"
    }

    inline = [data.template_file.cleanup.rendered] 
  }
}

# Set DNS servers on first DC
resource "null_resource" "first-dc-dns" {
  count      = var.deploy_mode != "NewDC" ? length(var.new_dc_name) == 1 ? 0 : 1 : 0
  depends_on = [ null_resource.cleanup ]

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = var.domain_admin_password
      host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[0]
      port        = var.dc_external_ssh_port[0] != "" ? var.dc_external_ssh_port[0] : 22
      script_path = "C:/Windows/Temp/terraform_%RAND%.bat"
      timeout     = "15m"
    }

    inline = [data.template_file.first-dc-dns[0].rendered]
  }
}

# Set DNS servers on secondary DCs
resource "null_resource" "secondary-dc-dns" {
  count      = var.deploy_mode != "NewDC" ? length(var.new_dc_name) == 1 ? 0 : length(var.new_dc_name) - 1 : 0
  depends_on = [ null_resource.first-dc-dns ]

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = var.domain_admin_password
      host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index + 1]
      port        = var.dc_external_ssh_port[count.index + 1] != "" ? var.dc_external_ssh_port[count.index + 1] : 22
      script_path = "C:/Windows/Temp/terraform_%RAND%.bat"
      timeout     = "15m"
    }

    inline = [data.template_file.secondary-dc-dns[0].rendered]
  }
}

# Set DNS servers on new DCs in existing domain
resource "null_resource" "new-dc-dns" {
  count      = var.deploy_mode == "NewDC" ? length(var.new_dc_name) : 0
  depends_on = [ null_resource.cleanup ]

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = var.existing_domain_user
      password    = var.existing_domain_password
      host        = var.external_ip != "" ? var.external_ip : var.dc_internal_ip[count.index]
      port        = var.dc_external_ssh_port[count.index] != "" ? var.dc_external_ssh_port[count.index] : 22
      script_path ="C:/Windows/Temp/terraform_%RAND%.bat"
      timeout     = "15m"
    }

    inline = [data.template_file.new-dc-dns[0].rendered]
  }
}