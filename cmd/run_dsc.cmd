powershell -ExecutionPolicy Bypass -Command "C:\Windows\Temp\adds_configuration.ps1 -deploy_mode ${deploy_mode} -new_dc_name ${new_dc_name} -internal_dc_ip ${internal_dc_ip} -new_domain_name ${new_domain_name} -dsrm_password ${dsrm_password} -domain_admin_password ${domain_admin_password} -existing_domain_name ${existing_domain_name} -existing_domain_user ${existing_domain_user} -existing_domain_password ${existing_domain_password} -existing_domain_dns ${existing_domain_dns}"