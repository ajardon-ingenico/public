#Requires -RunAsAdministrator

#Add KIOSK user inside Administrators group and change password
#Prompt for a password
$KioskCredentials=Get-Credential -Username "kiosk" -Message "Please enter a new secure password for kiosk Account into password field box"
$KioskPassword=$KioskCredentials.Password
#Change kiosk password and grant administrator rights
$UserAccount = Get-LocalUser -Name "kiosk"
$UserAccount | Set-LocalUser -Password $KioskPassword
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
& $PathNSSM install CoreDNS "C:\Program Files\CoreDNS\coredns.exe"
& $PathNSSM set CoreDNS Application "C:\Program Files\CoreDNS\coredns.exe"
& $PathNSSM set CoreDNS AppDirectory "C:\Program Files\CoreDNS"
& $PathNSSM set CoreDNS description "Local DNS Service"
& $PathNSSM set CoreDNS Start SERVICE_AUTO_START

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
$MessageBody = "Please start your Fortinet VPN Client connection                       Next step will start when you are successfully connected to the VPN and have network connectivity to BASTION"
$MessageTitle = "Manual operation required"
$Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

While(!(Test-Connection bastion.infra.eu.ginfra.net -Quiet -Count 1)){
    Write-Progress -Activity "VPN Connectivity" -Status "Waiting for network connectivity before joining BASTION domain"
    Start-Sleep -sec 1
}
################################################################################################################################################

#Join to BASTION domain
$DomainJoinCredentials=Get-Credential -Username "bastion.infra.eu.ginfra.net\domainjoin" -Message "Please enter the password provided for the domain join into password field box"
if(Add-Computer -DomainName "bastion.infra.eu.ginfra.net" -OUPath "OU=Computers,OU=BASTION,OU=TIER1,DC=bastion,DC=infra,DC=eu,DC=ginfra,DC=net" -Credential $DomainJoinCredentials) {
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::YesNoCancel
    $MessageIcon = [System.Windows.MessageBoxImage]::Exclamation
    $MessageBody = "Please press Yes to restart your computer - No if you plan to restart later on"
    $MessageTitle = "You are now part of BASTION Community"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
    if ($Result -eq "Yes") {
        Write-Host -ForegroundColor Green "Restarting computer"
        Start-Sleep -sec 5
        Restart-Computer -Force
    }
} else {
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::OK
    $MessageIcon = [System.Windows.MessageBoxImage]::Error
    $MessageBody = "Please run again the script to perfom the domain join"
    $MessageTitle = "Error during join domain"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
}
################################################################################################################################################
