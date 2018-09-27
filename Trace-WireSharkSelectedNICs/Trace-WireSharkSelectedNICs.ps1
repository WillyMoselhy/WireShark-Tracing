<#
.SYNOPSIS
    Utilizes Wireshark to trace traffic from selected NICs
.DESCRIPTION
    This script uses Wireshark's Dumpcap.exe to trace network traffic for selected NICs.
    Once the script starts it will query which adapters you wish to trace.
    Tracing can then be stopped by pressing any key.
.EXAMPLE
    PS C:\> .\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    The files will use the name "ComputerName_FileNumber_TimeStamp.pcap"
    File size will be 200 MB and it will create a maximum of 80 files.
.EXAMPLE
    PS C:\> .\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -TraceNamePrefix "$env:ComputerName_Test1" -FileSizeMB 120 -Files 5

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    The files will use the name "ComputerName_Test1_FileNumber_TimeStamp.pcap"
    Files size will be 120 MB and it will create a maximum of 5 files.
.EXAMPLE
    PS C:\> .\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    It will only capture traffic going to port 8080
.EXAMPLE
    PS C:\> .\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -Compress

    This will trace the selected NICs and compress the results in to C:\WireSharkTrace\ComputerName_Date_Time.zip file.
.INPUTS
    None.
.OUTPUTS
    None.
.LINK
https://github.com/WillyMoselhy/WireShark-Tracing/tree/master/Trace-WireSharkSelectedNICs
.LINK
https://plusontech.com/2018/09/25/powershell-script-trace-wiresharkselectednics-ps1-collect-wireshark-traces-from-multiple-network-adapters/
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true , Position = 1)]
    # Path where you wish to save the trace files.
    # If the folder does not exist it will be automatically created.
    [String] $TracePath,
    
    [Parameter(Mandatory = $false)]
    # Prefix name for the tracing files
    [string] $TraceNamePrefix = "$env:COMPUTERNAME", 
    
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
    # Compress files after completing the trace
    [switch] $Compress
)

#Logging Configuration
$ScriptMode = $false
$HostMode = $true
$Trace = ""

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
        Throw "Terminating Error: $message"
    }

#endregion: Logging Functions

#region: Checking Wireshark is installed
    WriteInfo "Checking Wireshark is installed"
    if(Test-Path -Path 'C:\Program Files\WireShark\dumpcap.exe'){
        WriteInfo "Found Wireshark's Dumpcap.exe"
    }
    else{
        WriteErrorAndExit "Wireshark is not installed - could not find: C:\Program Files\WireShark\dumpcap.exe"
    }
#endregion: Checking Wireshark is installed

#region: Validating trace location
    WriteInfo "Checking provided trace location" -WaitForResult
    if(Test-Path -Path $TracePath){
        WriteResult -Pass -message "Folder already exists: $TracePath"
        if($Compress){
            WriteInfo "Creating temporary folder to compress traces" -WaitForResult
            $SavePath = (New-Item -Path "$TracePath\Trace-WireSharkSelectedNICs_$(Get-Date -Format "yyMMddHHmmss")" -ItemType Directory).FullName
            $SavePath += "\"
            WriteResult -Success -message "Temporary folder created: $SavePath"
        }
        else{
            $SavePath = (Get-Item -Path $TracePath).FullName
        }
    }
    else{
        $SavePath = (New-Item -Path $TracePath -ItemType Directory).FullName
        WriteResult -Pass -message "Created new folder: $SavePath"
    }
#endregion: Validating trace location

#region: Get Network Adatpers from PowerShell
    WriteInfo "Getting list of active network adapters"
        $PSNICs = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}| Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed,DeviceID | Sort-Object Name
    WriteInfo "Found the following active adapters:" -AdditionalMultilineString ($PSNICs | Format-Table | Out-String)
    WriteInfo "Offering to select required adapter(s) using GridView"
    $SelectedNICs = $PSNICs | Out-GridView -Title "Please select NIC(s) to monitor"  -OutputMode Multiple
    if($SelectedNICs -eq $null){
        WriteErrorAndExit "No Adapters were selected"
    }
    WriteInfo "The following adapter(s) were selected" -AdditionalMultilineString ($SelectedNICs | Format-Table | Out-String )
#endregion: Get Network Adatpers from PowerShell

#region:Get WireShark NIC lists
    WriteInfo "Getting list of NICs using Dumpcap.exe -D -M"
    $WireSharkNICS = & "C:\Program Files\Wireshark\dumpcap.exe" -D -M |ForEach-Object{
        if($_ -match "(?<ID>\d+)\.\s\\Device\\NPF_\{(?<AdapterId>.{36})\}.*"){
            [PSCustomObject]@{
                Number = $matches.ID
                AdapterID = $matches.AdapterId
            }
        }
    }
    
    WriteInfo "Got the following list" -AdditionalMultilineString ($WireSharkNICS |Sort-Object Number | Format-Table Number,AdapterID | Out-String)

    WriteInfo "Matching list with Selected NICs"
    $WireSharkMatches = $WireSharkNICS | Where-Object {"{$($_.AdapterID)}" -in $SelectedNICs.DeviceID}
    WriteInfo "Matched the following NICs" -AdditionalMultilineString ($WireSharkMatches | Sort-Object Number | Format-Table Number,AdapterID | Out-String)
    if($WireSharkMatches.Count -eq $SelectedNICs.Count){
        WriteInfo "Found matches for all selected adapter NICs"
    }
    else{        
        WriteErrorAndExit "Could not match selected NICs to Wireshark" 
    }
#endregion: Get WireShark NIC lists

#region: Calculate dumpcap arguments
    WriteInfo "Calculating Dumpcap commands"
    
        $DumcapNICs = $WireSharkMatches | ForEach-Object{"-i $($_.Number)"}
        $DumpcapArgs = "$DumcapNICs -w $SavePath$TraceNamePrefix.pcap -b filesize:$($FileSizeMB*1024) -b files:$Files"
        if($CaptureFilter){
            $DumpcapArgs += " -f `"$CaptureFilter`""
        }
    
    WriteInfo "Dumpcap command will use these arguments" -AdditionalMultilineString "Dumpcap.exe $($DumpcapArgs | Format-Table | Out-String)"
#endregion: Calculate dumpcap arguments

#region: Run WireShark
    WriteInfo "Starting Wireshark trace" -WaitForResult
    
    $DumpcapProcess = Start-Process -FilePath 'C:\Program Files\Wireshark\dumpcap.exe' -ArgumentList $DumpcapArgs -PassThru -NoNewWindow
    WriteResult -Success -message "Wireshark is now running with process ID $($DumpcapProcess.Id)"
        Write-Host "Press any key to stop tracing ..."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
        $HOST.UI.RawUI.Flushinputbuffer()
    
    WriteInfo "Stopping trace" -WaitForResult
    $DumpcapProcess| Stop-Process
    WriteResult -Success -message "Trace stopped succefully"
#endregion: Run WireShark   

#region: Compress output and / or open location
    if($Compress){
        WriteInfo "Compressing results" -WaitForResult
        $ZipFileName ="$((Get-Item $TracePath).FullName)$TraceNamePrefix`_$(Get-Date -Format "yyMMdd-HHmmss").zip"
        Compress-Archive -Path "$SavePath*" -DestinationPath $ZipFileName -CompressionLevel Optimal
        Remove-Item -Path $SavePath -Recurse
        WriteResult -Success -message "Trace files compressed: $ZipFileName"
        WriteInfo "Opening trace location: $SavePath"
        explorer.exe "/select,$ZipFileName"
    }
    else{
        WriteInfo "Opening trace location: $SavePath"
        explorer.exe $SavePath
    }
#endregion: Compress output

    WriteInfoHighlighted "Script will now terminate"


