variable "deploy_mode" {
  type        = string
  default     = "NewForest"
  description = "Active Directory deploy mode (NewForest, NewDomain, NewDC)"
}

variable "domain_admin_password" {
  type        = string
  description = "Domain admin password"
}

variable "dsrm_password" {
  type        = string
  description = "Domain controller DSRM password"
}

variable "existing_domain_dns" {
  type        = list(string)
  default     = []
  description = "Existing domain DNS servers. Used for adding new domain or domain controllers. Leave blank for new forest"
}

variable "existing_domain_name" {
  type        = string
  default     = ""
  description = "Existing domain name. Used for adding new domain or domain controllers. Leave blank for new forest"
}

variable "existing_domain_password" {
  type        = string
  default     = ""
  description = "Domain user password. Used for adding new domain or domain controllers. Leave blank for new forest"
}

variable "existing_domain_user" {
  type        = string
  default     = ""
  description = "Domain user name (user@SOME.DOMAIN). Used for adding new domain or domain controllers. Leave blank for new forest"
}

variable "dc_external_ssh_port" {
  type        = list(string)
  description = "DC external SSH port numbers"
  default = []
}

variable "external_ip" {
  type        = string
  default     = ""
  description = "Org Edge external IP. Used for remote SSH connection from Internet"
}

variable "local_admin_password" {
  type = string
  description = "DC local administrator password"
}

variable "dc_internal_ip" {
  type        = list(string)
  description = "DC IP addresses"
}

variable "new_dc_name" {
  type        = list(string)
  description = "DC name"
}

variable "new_domain_name" {  
  type        = string
  description = "Active Directory domain name. Leave blank to add new DCs to existing domain"
}