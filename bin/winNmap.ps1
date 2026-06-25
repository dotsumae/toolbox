function Invoke-LotlPortScan {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [int[]]$Ports = @(
            21,22,23,25,53,80,88,110,111,135,139,143,389,443,445,464,
            587,593,636,873,993,995,1433,1521,2049,3306,3389,5432,
            5900,5985,5986,6379,8000,8080,8443,8888,9200,9300,27017
        ),

        [int]$Timeout = 300,

        [int]$Threads = 100,

        [switch]$Quiet
    )

    try {
        $TargetIp = ([System.Net.Dns]::GetHostAddresses($Target) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            Select-Object -First 1).IPAddressToString

        if (-not $TargetIp) {
            Write-Host "[-] Could not resolve IPv4 address for $Target" -ForegroundColor Red
            return
        }
    }
    catch {
        Write-Host "[-] Could not resolve target $Target" -ForegroundColor Red
        return
    }

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "[*] Target  : $Target"
        Write-Host "[*] IP      : $TargetIp"
        Write-Host "[*] Ports   : $($Ports.Count)"
        Write-Host "[*] Timeout : $Timeout ms"
        Write-Host "[*] Threads : $Threads"
        Write-Host ""
    }

    $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $Threads)
    $RunspacePool.Open()

    $ScriptBlock = {
        param($TargetIp, $Port, $Timeout)

        $Client = New-Object System.Net.Sockets.TcpClient

        try {
            $Async = $Client.BeginConnect($TargetIp, $Port, $null, $null)
            $Wait = $Async.AsyncWaitHandle.WaitOne($Timeout, $false)

            if ($Wait) {
                try {
                    $Client.EndConnect($Async)

                    [PSCustomObject]@{
                        Target = $TargetIp
                        Port   = $Port
                        State  = "Open"
                    }
                }
                catch {}
            }
        }
        catch {}
        finally {
            try { $Client.Close() } catch {}
            try { $Client.Dispose() } catch {}
        }
    }

    $Jobs = New-Object System.Collections.ArrayList

    foreach ($Port in $Ports) {
        $PowerShell = [PowerShell]::Create()
        $PowerShell.RunspacePool = $RunspacePool

        [void]$PowerShell.AddScript($ScriptBlock)
        [void]$PowerShell.AddArgument($TargetIp)
        [void]$PowerShell.AddArgument($Port)
        [void]$PowerShell.AddArgument($Timeout)

        $Handle = $PowerShell.BeginInvoke()

        [void]$Jobs.Add([PSCustomObject]@{
            PowerShell = $PowerShell
            Handle     = $Handle
            Port       = $Port
        })
    }

    $Results = New-Object System.Collections.ArrayList
    $Total = $Jobs.Count
    $Done = 0

    while ($Jobs.Count -gt 0) {
        for ($i = $Jobs.Count - 1; $i -ge 0; $i--) {
            $Job = $Jobs[$i]

            if ($Job.Handle.IsCompleted) {
                $Output = $Job.PowerShell.EndInvoke($Job.Handle)

                foreach ($Item in $Output) {
                    [void]$Results.Add($Item)

                    if (-not $Quiet) {
                        Write-Host ("[+] OPEN  {0}:{1}" -f $Item.Target, $Item.Port) -ForegroundColor Green
                    }
                }

                $Job.PowerShell.Dispose()
                $Jobs.RemoveAt($i)
                $Done++

                if (-not $Quiet) {
                    Write-Progress `
                        -Activity "Scanning $TargetIp" `
                        -Status "$Done / $Total ports completed" `
                        -PercentComplete (($Done / $Total) * 100)
                }
            }
        }

        Start-Sleep -Milliseconds 25
    }

    if (-not $Quiet) {
        Write-Progress -Activity "Scanning $TargetIp" -Completed
        Write-Host ""
    }

    $RunspacePool.Close()
    $RunspacePool.Dispose()

    $Results | Sort-Object Port
}
``
