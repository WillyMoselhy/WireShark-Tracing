# This script allows you to select adapters you wish to trace using WireShark
# You need to have WireShark installed (x64 if using 64-bit OS) to work properly
# You can edit the location by changing the $TraceLocation variable below

#WireShark Configuration
$TraceLocation = "C:\WireSharkTrace"
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
        Throw "Terminating Error"
    }

#endregion: Logging Functions

#region: Validating trace location
    WriteInfo "Checking provided trace location" -WaitForResult
    if(Test-Path -Path $TraceLocation){
        WriteResult -Pass
    }
    else{
        New-Item -Path $TraceLocation -ItemType Directory | Out-Null
        WriteResult -Pass -message "Created new folder: $TraceLocation"
    }
#endregion: Validating trace location

#region: Get Network Adatpers from PowerShell
    WriteInfo "Getting list of active network adapters"
        $PSNICs = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}| Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed,DeviceID | Sort-Object Name
    WriteInfo "Found the following active adapters:" -AdditionalMultilineString ($PSNICs | Format-Table | Out-String)
    WriteInfo "Offering to select required adapter(s) using gridview"
    $SelectedNICs = $PSNICs | Out-GridView -Title "Please select NIC(s) to monitor"  -OutputMode Multiple
    if($SelectedNICs -eq $null){
        throw "No Adapters were selected"
    }
    WriteInfo "The following adapter(s) were selected" -AdditionalMultilineString ($SelectedNICs | Format-Table | Out-String )
#endregion: Get Network Adatpers from PowerShell

#region:Get WireShark NIC lists
    WriteInfo "Getting list of NICs using WireShark dumpcap.exe"
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
        WriteInfo "Found matches for all selected cluster NICs"
    }
    else{        
        WriteErrorAndExit "Could not match selected NICs to wireshark" 
    }
#endregion: Get WireShark NIC lists

#region: Calculate TShark arguments
    WriteInfo "Calculating the tshark commands for each node"
    
        $TSharkNICs = $WireSharkMatches | Where-Object {$_.PSComputerName -eq $Node} | ForEach-Object{"-i $($_.Number)"}
        $TSharkArgs = "$TsharkNICs -w $TraceLocation\$env:COMPUTERNAME.pcap -b filesize:204800 -b files:80"
    
    WriteInfo "TShark command will use these arguments" -AdditionalMultilineString ($TSharkArgs | Format-Table | Out-String)
#endregion: Calculate TShark arguments

#region: Run WireShark until a node crashes
    WriteInfo "Starting wireshark trace" -WaitForResult
    
    $TSharkProcess = Start-Process -FilePath 'C:\Program Files\Wireshark\tshark.exe' -ArgumentList $TSharkArgs -PassThru -NoNewWindow
    WriteResult -Success -message "Wireshark is now running with process ID $($TSharkProcess.Id)"
        Write-Host "Press any key to stop tracing ..."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
        $HOST.UI.RawUI.Flushinputbuffer()
    
    WriteInfo "Stopping trace" -WaitForResult
    $TSharkProcess| Stop-Process
    WriteResult -Success -message "Trace stopped succefully"
    WriteInfo "Opening trace location: $TraceLocation"
    explorer.exe $TraceLocation
    WriteInfoHighlighted "Script will now terminate"


