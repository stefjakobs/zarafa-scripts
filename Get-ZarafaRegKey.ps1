$repath64 = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Zarafa\Client"
$repath32 = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Zarafa\Client"
if (Test-Path $repath64) {
	$regkey = Get-Item -Path $repath64 | Get-ItemProperty 	
}
elseif (Test-Path $repath32) {
 	$regkey = Get-Item -Path $repath32 | Get-ItemProperty 
}
else {
 	$regkey = $null
}
if ($regkey -ne $null) {
	Write-Host "PSPath: $($regkey.PSPath)"
	Write-Host "Version: $($regkey.Version)"
	Write-Host "InstallDir: $($regkey.InstallDir)"
}
else {
	Write-Host "No suitable registry key found"
}
 
 
 
 