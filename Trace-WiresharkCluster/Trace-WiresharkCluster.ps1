<#
.SYNOPSIS
    Start Wireshark tracing on all cluster nodes until we get event 1135 on each node.
.DESCRIPTION
    This script uses Wireshark's Dumpcap.exe to trace network traffic for all active NICs on
    all active cluster nodes.
    The script uses background jobs to trigger and monitor Dumpcap.exe so you are able to
    see which status from each node.
    Jobs will automatically stop when event 1135 is triggered on a node or if Dumpcap.exe exits.
.EXAMPLE
    PS C:\> .\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace

    This will trace and save to C:\WireSharkTrace folder on each of the nodes.
.EXAMPLE
    PS C:\> .\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -ClusterName ExampleCluster.domain.com

    This will trace all NICs on a remote cluster and save to C:\WireSharkTrace folder.
.EXAMPLE
    PS C:\> .\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"

    This will trace only traffic on port 8080
.EXAMPLE
    PS C:\> .\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"

    This will trace all NICs and save to C:\WireSharkTrace folder.
    It will only capture traffic going to port 8080
.EXAMPLE
    PS C:\> .\Trace-WiresharkCluster.ps1 -TracePath C:\WireSharkTrace -LogPath "C:\WireSharkClusterTrace.log"

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    In addition to the on-screen messages, it will all also save the log to "C:\WireSharkClusterTrace.log"
.INPUTS
    None.
.OUTPUTS
    None.
.LINK
https://github.com/WillyMoselhy/WireShark-Tracing/tree/master/Trace-WiresharkCluster
.LINK
https://plusontech.com/2018/10/02/powershell-script-trace-wiresharkcluster-ps1-collect-wireshark-traces-from-all-failover-cluster-nodes/
#>

Param(
    [Parameter(Mandatory = $false)]
    # Name of cluster to collect the traces from
    # If not defined the script will attempt to connect to the local cluster.
    [String] $ClusterName = "localhost",

    [Parameter(Mandatory = $true)]
    # Path where you wish to save the trace files.
    # If the folder does not exist it will be automatically created.
    # The path must not end with "\" and must be a local path.
    # Example: C:\WiresharkTrace\TraceOne
    [ValidatePattern("\w:\\.+(?<!\\)$")]
    [String] $TracePath,

    [Parameter(Mandatory = $false)]
    # Filter to use while capturing the traffic
    # Use the Wireshark filtering syntax
    # If not defined will capture all trafic
    [string] $CaptureFilter, 
  
    [Parameter(Mandatory = $false)]
    # Maximum trace files size. Default is 200 MB
    [int] $FileSizeMB = 200, 
    
    [Parameter(Mandatory = $false)]
    # Maximum number of traces to keep. Default is 80
    [int] $Files      = 80,

    [Parameter(Mandatory = $false)]
    # Path to save the log
    # If not defined then no log is saved.
    [String] $LogPath
)
#Wireshark Configuration

#Script Configuration
if($LogPath){ # Logs will be saved to disk at the specified location
    $ScriptMode=$true
}
else{ # Logs will not be saved to disk
    $ScriptMode = $false
}
$LogLevel = 0
$Trace    = ""

# This script is chatty and will always show on-screen output
$HostMode = $true

$ErrorActionPreference = "Stop"
#region: Logging Functions 
    #This writes the actual output - used by other functions
    function WriteLine ([string]$line,[string]$ForegroundColor, [switch]$NoNewLine){
        if($Script:ScriptMode){
            if($NoNewLine) {
                $Script:Trace += "$line"
            }
            else {
                $Script:Trace += "$line`r`n"
            }
            Set-Content -Path $script:LogPath -Value $Script:Trace
        }
        if($Script:HostMode){
            $Params = @{
                NoNewLine       = $NoNewLine -eq $true
                ForegroundColor = if($ForegroundColor) {$ForegroundColor} else {"White"}
            }
            Write-Host $line @Params
        }
    }
    
    #This handles informational logs
    function WriteInfo([string]$message,[switch]$WaitForResult,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){
        if($WaitForResult){
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message" -NoNewline
        }
        else{
            WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  
        }
        if($AdditionalStringArray){
                foreach ($String in $AdditionalStringArray){
                    WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$String"     
                }
       
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String"     
            }
       
        }
    }

    #This writes results - should be used after -WaitFor Result in WriteInfo
    function WriteResult([string]$message,[switch]$Pass,[switch]$Success){
        if($Pass){
            WriteLine " - Pass" -ForegroundColor Cyan
            if($message){
                WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Cyan
            }
        }
        if($Success){
            WriteLine " - Success" -ForegroundColor Green
            if($message){
                WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)`t$message" -ForegroundColor Green
            }
        } 
    }

    #This write highlighted info
    function WriteInfoHighlighted([string]$message,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){ 
        WriteLine "[$(Get-Date -Format hh:mm:ss)] INFO:    $("`t" * $script:LogLevel)$message"  -ForegroundColor Cyan
        if($AdditionalStringArray){
            foreach ($String in $AdditionalStringArray){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
            }
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Cyan
            }
        }
    }

    #This write warning logs
    function WriteWarning([string]$message,[string[]]$AdditionalStringArray,[string]$AdditionalMultilineString){ 
        WriteLine "[$(Get-Date -Format hh:mm:ss)] WARNING: $("`t" * $script:LogLevel)$message"  -ForegroundColor Yellow
        if($AdditionalStringArray){
            foreach ($String in $AdditionalStringArray){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
            }
        }
        if($AdditionalMultilineString){
            foreach ($String in ($AdditionalMultilineString -split "`r`n" | Where-Object {$_ -ne ""})){
                WriteLine "[$(Get-Date -Format hh:mm:ss)]          $("`t" * $script:LogLevel)`t$String" -ForegroundColor Yellow
            }
        }
    }

    #This logs errors
    function WriteError([string]$message){
        WriteLine ""
        WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t`t" * $script:LogLevel)$message" -ForegroundColor Red
        
    }

    #This logs errors and terminated script
    function WriteErrorAndExit($message){
        WriteLine "[$(Get-Date -Format hh:mm:ss)] ERROR:   $("`t" * $script:LogLevel)$message"  -ForegroundColor Red
        Write-Host "Press any key to continue ..."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
        $HOST.UI.RawUI.Flushinputbuffer()
        Throw "Terminating Error"
    }

#endregion: Logging Functions

#region: Cluster network information
WriteInfo "Collecting cluster information"
$LogLevel++

    WriteInfo "Getting list of cluster nodes on $ClusterName"
    $ClusterNodes = Get-ClusterNode -Cluster $ClusterName
    $LogLevel++
        WriteInfo "Found the following cluster nodes" -AdditionalMultilineString ($ClusterNodes | Format-Table | Out-String)

        #Excluding nodes that are not currently UP
        $OfflineNodes = $ClusterNodes | Where-Object {$_.State -ne "Up"}
        if($OfflineNodes){
            WriteWarning "The following nodes are not Up and will NOT be included in the trace" -AdditionalStringArray $OfflineNodes.Name
            $ClusterNodes = $ClusterNodes | Where-Object {$_.State -eq "Up"}
        }
        else {
            WriteInfoHighlighted "All nodes are online."
        }
    $LogLevel--

    WriteInfo "Creating list of cluster network adapters per node"
    $ClusterNICs = Get-ClusterNetworkInterface | Where-Object {$_.Node -in $ClusterNodes.Name} | Select-Object Node,Adapter,Address,State,AdapterId  | Sort-Object Node
    $LogLevel++    
        WriteInfo "Found the following NICs" -AdditionalMultilineString ($ClusterNICs | Format-Table | Out-String)

        #Excluding NICs that are not currently Up
        $OfflineNICs = $ClusterNICs | Where-Object {$_.State -ne "Up"}
        if($OfflineNICs){
            WriteWarning "The following NICs are not Up and will NOT be included in the trace" -AdditionalMultilineString ($OfflineNICs | Format-Table | Out-String)
            $ClusterNICs = $ClusterNICs | Where-Object {$_.State -eq "Up"}
        }
        else{
            WriteInfo "All NICs are online."
        }
    $LogLevel--

$LogLevel--
#endregion: Cluster network information

#region: Validate WireShark is installed on the nodes
WriteInfo "Confirming Wireshark is installed on cluster nodes"
$LogLevel++
        WriteInfo "Connecting to nodes to check if we can find C:\Program Files\Wireshark\dumpcap.exe" -WaitForResult
        $WiresharkInstalled = Invoke-Command -ComputerName $ClusterNICs.Node -ScriptBlock {
            [PSCustomObject]@{
                DumpcapFound = Test-Path -Path "C:\Program Files\Wireshark\dumpcap.exe"
            }
        }
        $WiresharkInstalled.DumpcapFound -notcontains $false
        #WriteErrorAndExit -message "Wireshark not installed on all nodes."
        if($WiresharkInstalled.DumpcapFound -notcontains $false){
            WriteResult -Pass
        }
        else{
            $String = ($WiresharkInstalled | Format-Table PSComputerName,DumpcapFound| Out-String)
            WriteWarning -message "Could not validate Wireshark exists on all nodes" -AdditionalMultilineString $String
            WriteErrorAndExit -message "Wireshark is not installed on all nodes."
        }
$LogLevel--
#endregion: Validate WireShark is installed on the nodes

#region:Get Wireshark NIC lists
WriteInfo "Collecting Wireshark info"
$LogLevel++
    
    WriteInfo "Getting list of NICs using Wireshark Dumpcap.exe"
    $WiresharkNICsList = Invoke-Command -ComputerName $ClusterNICs.Node -ScriptBlock {
        $WiresharkNICS = & "C:\Program Files\Wireshark\dumpcap.exe" -D -M 
        $WiresharkNICS | ForEach-Object{
            if($_ -match "(?<ID>\d+)\.\s\\Device\\NPF_\{(?<AdapterId>.{36})\}.*"){
                [PSCustomObject]@{
                    Number = $matches.ID
                    AdapterID = $matches.AdapterId
                }
            }
        }
    }
    WriteInfo "Got the following list" -AdditionalMultilineString ($WiresharkNICsList |Sort-Object PSComputerName,Number | Format-Table PSComputerName,Number,AdapterID | Out-String)

    WriteInfo "Matching list with Cluster NICs"
    $WiresharkMatches = $WiresharkNICsList | Where-Object {$_.AdapterID -in $ClusterNICs.AdapterID}
    WriteInfo "Matched the following NICs" -AdditionalMultilineString ($WiresharkMatches | Sort-Object PSComputerName,Number | Format-Table PSComputerName,Number,AdapterID | Out-String)
    if($WiresharkMatches.Count -eq $ClusterNICs.Count){
        WriteInfoHighlighted "Found matches for all active cluster NICs"
    }
    else{        
        WriteErrorAndExit "Could not match cluster NICs to wireshark" 
    }

$LogLevel--
#endregion: Get Wireshark NIC lists

#region: Calculate Dumpcap arguments
    WriteInfo "Calculating the Dumpcap commands for each node"
    $DumpcapArgs = foreach ($Node in ($WiresharkMatches.PSComputerName | Select-Object -Unique | Sort-Object)){
        $DumpcapNICs = $WiresharkMatches | Where-Object {$_.PSComputerName -eq $Node} | ForEach-Object{"-i $($_.Number)"}
        $ArgumentString =  "$DumpcapNICs -w $TracePath\$Node.pcap -b filesize:$($FileSizeMB * 1024) -b files:$Files"
        if($CaptureFilter){
            $ArgumentString += " -f `"$CaptureFilter`""
        }
        [PSCustomObject]@{
            Node = $Node
            Args = $ArgumentString
        }
    }
    WriteInfo "Dumpcap command will use these arguments on each node" -AdditionalMultilineString ($DumpcapArgs | Format-Table | Out-String)
#endregion: Calculate Dumpcap arguments

#region: Run Wireshark until a node crashes
    WriteInfo "Starting wireshark in remote jobs"
    $Jobs = foreach($Entry in $DumpcapArgs){
        Invoke-Command -ComputerName $Entry.Node -ArgumentList $Entry,$TracePath -AsJob -ScriptBlock {
            Param ($Entry,$TracePath)
            #region: Validating trace location
            if(Test-Path -Path $TracePath){
                $SavePath = (Get-Item -Path $TracePath).FullName
            }
            else{
                $SavePath = (New-Item -Path $TracePath -ItemType Directory).FullName
            }
            #endregion: Validating trace location 

            $ArgumentList = $Entry.Args
            New-Item -Path C:\WiresharkTrace -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            $DumpcapProcess = Start-Process -FilePath 'C:\Program Files\Wireshark\Dumpcap.exe' -ArgumentList $ArgumentList -PassThru
            $EventOccured = $false
            While (!($EventOccured)){
                #Checking if Event 1135 occured
                $Events = Get-WinEvent -FilterHashtable @{StartTime = (Get-Date).AddSeconds(-5);Id = 1135;LogName = "System"} -ErrorAction SilentlyContinue
                if($Events){
                    $EventOccured = $true
                }
                #Checking if Dumpcap.exe is no longer running
                If($DumpcapProcess.HasExited){
                    $EventOccured = $true
                    $Events = "Dumpcap exited with exit code: $($DumpcapProcess.ExitCode)"
                }
                Start-Sleep -Seconds 1
            }
            $DumpcapProcess| Stop-Process
            
            return $Events
        }
    }
    WriteInfo "The following jobs are now waiting for event 1135 to stop" -AdditionalMultilineString ($Jobs | Format-Table | Out-String)
#endregion: Run Wireshark until a node crashes

#region: Monitor running jobs
    WriteInfo "Monitoring Jobs"
    $CompletedJobIds = @()
    While ($Jobs | Where-Object {$_.State -eq "Running"}){
        $CompletedJobs = $Jobs | Where-Object {$_.State -eq "Completed" -and $_.id -notin $CompletedJobIds}
        if($CompletedJobs){
            $CompletedJobs | ForEach-Object{
                $JobID = $_.Id
                $JobNode = $_.Location
                $JobResult = $_ | Receive-Job
                WriteInfoHighlighted "Job $JobID on $JobNode returned the event below" -AdditionalMultilineString ($JobResult | Format-List | Out-String -Width 100)
                WriteInfo "Job monitor status" -AdditionalMultilineString ($Jobs | Format-Table | Out-String)
                $CompletedJobIds += $JobID
            }
        }
        Start-Sleep -Seconds 1
    }
    WriteInfo "No more jobs are running. Final status:" -AdditionalMultilineString ($Jobs | Format-Table | Out-String)
#endregion: Monitor running jobs