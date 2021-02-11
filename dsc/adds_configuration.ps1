param (
    [string]$deploy_mode,
    [string]$new_dc_name,
    [string]$dc_internal_ip,
    [string]$new_domain_name,
    [string]$dsrm_password, 
    [string]$domain_admin_password,
    [string]$existing_domain_name,
    [string]$existing_domain_user,
    [string]$existing_domain_password,
    [string]$existing_domain_dns
)

Configuration ADDSSetup
{
    # Import DSC resources
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc

    # Install Windows features on all nodes
    Node $ConfigData.AllNodes.NodeName
    {
        WindowsFeature 'Install_ADDS_Features'
        {
            Name                 = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
        }
          
        WindowsFeature 'Install_RSAT'
        {
            Name                 = 'RSAT-ADDS'
            Ensure               = 'Present'
            IncludeAllSubFeature = $true
        }
    }

    # Deploy forest root DC
    Node $ConfigData.AllNodes.Where({$_.Role -eq 'ForestRoot'}).NodeName
    {
        User 'Set_local_admin_password'
        {
            UserName               = 'Administrator'
            Password               = $ConfigData.ADDomain.NewDomainCreds
        }

        ADDomain 'New_Domain'
        {
            DomainName                    = $ConfigData.ADDomain.NewDomainName
            Credential                    = $ConfigData.ADDomain.NewDomainCreds
            SafemodeAdministratorPassword = $ConfigData.ADDomain.DsrmCreds
            ForestMode                    = 'WinThreshold'

            DependsOn = '[WindowsFeature]Install_RSAT'
        }
    }

    # Deploy new domain root DC
    Node $ConfigData.AllNodes.Where({$_.Role -eq 'DomainRoot'}).NodeName
    {
        User 'Set_local_admin_password'
        {
            UserName               = 'Administrator'
            Password               = $ConfigData.ADDomain.NewDomainCreds
        }
        
        DnsServerAddress 'Configure_DNS'
        {
            Address        = $ConfigData.ADDomain.ExistingDomainDns
            InterfaceAlias = $ConfigData.DnsConfig.EthernetAdapterName
            AddressFamily  = 'IPv4'
            Validate       = $false

            DependsOn = '[WindowsFeature]Install_RSAT'
        }

        ADDomain 'New_Domain'
        {
            DomainName                    = $ConfigData.ADDomain.ChildDomainName
            Credential                    = $ConfigData.ADDomain.ExistingDomainCreds
            SafemodeAdministratorPassword = $ConfigData.ADDomain.DsrmCreds
            ParentDomainName              = $ConfigData.ADDomain.ParentDomainName

            DependsOn = '[DnsServerAddress]Configure_DNS'
        }
    }

    # Deploy secondary DCs in new forest or in new domain
    Node $ConfigData.AllNodes.Where({$_.Role -eq 'SecondaryDC'}).NodeName
    {    
        User 'Set_local_admin_password'
        {
            UserName               = 'Administrator'
            Password               = $ConfigData.ADDomain.NewDomainCreds
        }
        
        DnsServerAddress 'Configure_DNS'
        {
            Address               = $ConfigData.ADDomain.FirstDcIp
            InterfaceAlias        = $ConfigData.DnsConfig.EthernetAdapterName
            AddressFamily         = 'IPv4'
            Validate              = $false
        }
                   
        WaitForAll 'Wait_First_DC_Availability'
        {
            ResourceName      = '[ADDomain]New_Domain'
            NodeName          = $ConfigData.AllNodes.Where({$_.Role -eq 'ForestRoot' -or $_.Role -eq 'DomainRoot'}).NodeName
            RetryIntervalSec  = 60
            RetryCount        = 30
  
            DependsOn = '[DnsServerAddress]Configure_DNS'
        }

        WaitForADDomain 'Wait_Domain_Availability'
        {
            DomainName = $ConfigData.ADDomain.NewDomainName
            Credential = $ConfigData.ADDomain.NewDomainCreds
                
            DependsOn  = '[WaitForAll]Wait_First_DC_Availability'
        }
  
        ADDomainController 'New_DC'
        {
            DomainName                    = $ConfigData.ADDomain.NewDomainName
            Credential                    = $ConfigData.ADDomain.NewDomainCreds
            SafeModeAdministratorPassword = $ConfigData.ADDomain.DsrmCreds
  
            DependsOn = '[WaitForADDomain]Wait_Domain_Availability'
        }
    }

    # Deploy new DCs in existing domain
    Node $ConfigData.AllNodes.Where({$_.Role -eq 'NewDC'}).NodeName
    {   
        DnsServerAddress 'Configure_DNS'
        {
            Address               = $ConfigData.ADDomain.ExistingDomainDns
            InterfaceAlias        = $ConfigData.DnsConfig.EthernetAdapterName
            AddressFamily         = 'IPv4'
            Validate              = $false
        }

        ADDomainController 'New_DC'
        {
            DomainName                    = $ConfigData.ADDomain.ExistingDomainName
            Credential                    = $ConfigData.ADDomain.JoinDomainCreds
            SafeModeAdministratorPassword = $ConfigData.ADDomain.DsrmCreds

            DependsOn = '[DnsServerAddress]Configure_DNS'
        }
    }
}

# Get first network adapter name
$EthernetAdapterName = (Get-NetAdapter | Select-Object -First 1).Name

# Get new child domain name
$ChildDomainName = ($new_domain_name.split("."))[0]

# Get parent domain name
$ParentDomainName = $new_domain_name.Replace(($new_domain_name.split(".")[0]+"."), "")

# Get DC names
$DcNames = $new_dc_name.split(",")
$FirstDc = $DcNames[0]
$SecondaryDcs = $DcNames | Select-Object -Skip 1

# Get DSRM creds
$DsrmCreds = New-Object System.Management.Automation.PSCredential("Administrator",(ConvertTo-SecureString -String $dsrm_password -AsPlainText -Force))

# Get credentials
if ($domain_admin_password){
    $NewDomainCreds = New-Object System.Management.Automation.PSCredential("Administrator@$new_domain_name",(ConvertTo-SecureString -String $domain_admin_password -AsPlainText -Force))
}

if ($existing_domain_user) {
    $ExistingDomainCreds = New-Object System.Management.Automation.PSCredential($existing_domain_user,(ConvertTo-SecureString -String $existing_domain_password -AsPlainText -Force))
}

# Get existing domain DNS server list
$ExistingDomainDns = $existing_domain_dns.split(",")

# Get first DC IP address 
$FirstDcIp = ($dc_internal_ip.split(","))[0]

# Get configuration data
$ConfigData = @{   
    
    AllNodes = @(    
        @{  
            NodeName             = "*"
            CertificateFile      = "C:\Windows\Temp\DscEncryptionCert.cer"
            PSDscAllowDomainUser = $true
        }
    )

    ADDomain = @{
        DsrmCreds = $DsrmCreds
    }

    DnsConfig = @{
        EthernetAdapterName = $EthernetAdapterName
    }
}

switch ($deploy_mode ) {
    
    "NewForest" {
        
        # Roles configuration
        $ConfigData.AllNodes += @{NodeName = $FirstDc; Role = 'ForestRoot'}
        if ($SecondaryDcs) {
                foreach ($DcName in $SecondaryDcs) {
                $ConfigData.AllNodes += @{NodeName = $DcName; Role = 'SecondaryDC'}
            }
        }

        # Domain data
        $ConfigData.ADDomain += @{
            NewDomainName   = $new_domain_name
            FirstDcIp       = $FirstDcIp
            NewDomainCreds  = $NewDomainCreds
            JoinDomainCreds = $NewDomainCreds
        }
    }

    "NewDomain" {
        
        # Roles configuration
        $ConfigData.AllNodes += @{NodeName = $FirstDc; Role = 'DomainRoot'}
        if ($SecondaryDcs) {
            foreach ($DcName in $SecondaryDcs) {
                $ConfigData.AllNodes += @{NodeName = $DcName; Role = 'SecondaryDC'}
            }
        }

        # Domain data
        $ConfigData.ADDomain += @{
            NewDomainName       = $new_domain_name
            ChildDomainName     = $ChildDomainName
            FirstDcIp           = $FirstDcIp
            NewDomainCreds      = $NewDomainCreds
            ParentDomainName    = $ParentDomainName
            ExistingDomainDns   = $ExistingDomainDns
            ExistingDomainCreds = $ExistingDomainCreds
            JoinDomainCreds     = $NewDomainCreds
        }
    }

    "NewDC" {
        
        # Roles configuration
        foreach ($DcName in $DcNames) {
            $ConfigData.AllNodes += @{NodeName = $DcName; Role = 'NewDC'}
        }
        
        # Domain data
        $ConfigData.ADDomain += @{
            ExistingDomainName  = $existing_domain_name
            ExistingDomainDns   = $ExistingDomainDns
            JoinDomainCreds     = $ExistingDomainCreds
        }
    }
}

ADDSSetup -ConfigurationData $ConfigData -OutputPath C:\Windows\Temp
Start-DscConfiguration -ComputerName $env:COMPUTERNAME -Path 'C:\Windows\Temp' -Wait -Force -Verbose