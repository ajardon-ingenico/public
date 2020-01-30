#Requires -RunAsAdministrator

#Add KIOSK user inside Administrators group and change password
$Password = Read-Host "Enter new password for Kiosk Account" -AsSecureString
$UserAccount = Get-LocalUser -Name "kiosk"
$UserAccount | Set-LocalUser -Password $Password
Add-LocalGroupMember -Group "Administrators" -Member "kiosk"
################################################################################################################################################

#CoreDNS Installation
#Create Folder
$Path="C:\Program Files\CoreDNS"
if(!(Test-path $Path)) {New-Item -ItemType Directory -Force -Path $Path}
#Download required files
$headers = @{
  'X-JFrog-Art-Api' = "AKCp5e3p2HXDwhds9M6uELLMdTyjn3zEfPECEjKVvDuJfALjXgY6s5Q5diGTp7zye6dMXUaj7"
  "Content-Type" = "application/json"
  "Accept" = "application/json"
}
Invoke-WebRequest -Headers $headers -Uri "https://artifactory.tunz.com/artifactory/list/gl-windows/applications/coredns/coredns.exe" -OutFile "C:\Program Files\CoreDNS\coredns.exe"
Invoke-WebRequest -Headers $headers -Uri "https://artifactory.tunz.com/artifactory/list/gl-windows/applications/coredns/Corefile" -OutFile "C:\Program Files\CoreDNS\Corefile"
Invoke-WebRequest -Headers $headers -Uri "https://artifactory.tunz.com/artifactory/list/gl-windows/applications/coredns/nssm.exe" -OutFile "C:\Program Files\CoreDNS\nssm.exe"

#Install CoreDNS as service
$PathNSSM="C:\Program Files\CoreDNS\nssm.exe"
$PathNSSM install CoreDNS "C:\Program Files\CoreDNS\coredns.exe"
$PathNSSM set CoreDNS Application "C:\Program Files\CoreDNS\coredns.exe"
$PathNSSM set CoreDNS AppDirectory "C:\Program Files\CoreDNS"
$PathNSSM set CoreDNS description "Local DNS Service"
$PathNSSM set CoreDNS Start SERVICE_AUTO_START

#Start CoreDNS Service
While(!(Get-Service -Name "CoreDNS" -ErrorAction SilentlyContinue)){
    Write-Progress -Activity "CoreDNS Service" -Status "Waiting for CoreDNS service to be ready"
    Start-Sleep -sec 1
}
Start-Service CoreDNS
################################################################################################################################################

#Set 127.0.0.1 as DNS Server on Wi-Fi and Ethernet Adapter - Required for CoreDNS
Get-NetAdapter -Name "Wi-Fi","Ethernet" | Set-DnsClientServerAddress -ServerAddresses ("127.0.0.1")
################################################################################################################################################

#Waiting VPN connectivity
Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::OK
$MessageIcon = [System.Windows.MessageBoxImage]::Exclamation
$MessageBody = "Please start your Fortinet VPN Client connection"
$MessageTitle = "Manual operation required"
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

While(!(Test-Connection bastion.infra.eu.ginfra.net -Quiet -Count 1)){
    Write-Progress -Activity "VPN Connectivity" -Status "Waiting for network connectivity before joining BASTION domain"
    Start-Sleep -sec 1
}
################################################################################################################################################

#Join to BASTION domain
Add-Computer -DomainName "bastion.infra.eu.ginfra.net" -OUPath "OU=Computers,OU=BASTION,OU=TIER1,DC=bastion,DC=infra,DC=eu,DC=ginfra,DC=net"

Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::OK
$MessageIcon = [System.Windows.MessageBoxImage]::Exclamation
$MessageBody = "Please restart your computer"
$MessageTitle = "You are now part of BASTION Community"
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
################################################################################################################################################
