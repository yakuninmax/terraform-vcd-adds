powershell -ExecutionPolicy ByPass -Command "Set-DnsClientServerAddress -InterfaceAlias ((Get-NetAdapter | Select-Object -First 1).Name) -ServerAddresses ${dns_servers}"