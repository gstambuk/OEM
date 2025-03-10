function Harden-PrivilegeRights {
    $privilegeSettings = @'
[Privilege Rights]
SeDenyNetworkLogonRight = *S-1-5-11
SeDenyRemoteInteractiveLogonRight = *S-1-5-11
SeNetworkLogonRight=
SeRemoteShutdownPrivilege=
SeDebugPrivilege=
SeRemoteInteractiveLogonRight=
'@
    $cfgPath = "C:\secpol.cfg"
    secedit /export /cfg $cfgPath /quiet
    $privilegeSettings | Out-File -Append -FilePath $cfgPath -ErrorAction SilentlyContinue
    secedit /configure /db c:\windows\security\local.sdb /cfg $cfgPath /areas USER_RIGHTS /quiet
    Remove-Item $cfgPath -Force -ErrorAction SilentlyContinue
}

Harden-PrivilegeRights 