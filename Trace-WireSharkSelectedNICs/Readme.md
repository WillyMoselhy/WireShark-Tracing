# Trace-WireSharkSelectedNICs.ps1
Use this script to start tracing of selected NICs using WireShark

Read more about it on [PlusOnTech.com](https://plusontech.com/2018/09/25/powershell-script-trace-wiresharkselectednics-ps1-collect-wireshark-traces-from-multiple-network-adapters/ "PlusOnTech.com post about Trace-WireSharkSelectedNICs script").
## Examples
```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace
```

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    The files will use the name "ComputerName_FileNumber_TimeStamp.pcap"
    File size will be 200 MB and it will create a maximum of 80 files.

```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -TraceNamePrefix "$env:ComputerName_Test1" -FileSizeMB 120 -Files 5
```

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    The files will use the name "ComputerName_Test1_FileNumber_TimeStamp.pcap"
    Files size will be 120 MB and it will create a maximum of 5 files.

```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"
```

    This will trace the selected NICs and save to C:\WireSharkTrace folder.
    It will only capture traffic going to port 8080

```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -Compress
```

    This will trace the selected NICs and compress the results in to C:\WireSharkTrace\ComputerName_Date_Time.zip file.
