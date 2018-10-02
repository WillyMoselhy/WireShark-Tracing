# Trace-WireSharkSelectedNICs.ps1
Use this script to start tracing of selected NICs using WireShark

Read more about it on [PlusOnTech.com](https://plusontech.com/2018/09/25/powershell-script-trace-wiresharkselectednics-ps1-collect-wireshark-traces-from-multiple-network-adapters/ "PlusOnTech.com post about Trace-WireSharkSelectedNICs script").
## Examples
* Trace the selected NICs and save to C:\WireSharkTrace folder.
```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace
```
The files will use the name "ComputerName_FileNumber_TimeStamp.pcap"
File size will be 200 MB and it will create a maximum of 80 files.

* Trace the selected NICs and save to C:\WireSharkTrace folder.
```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -TraceNamePrefix "$env:ComputerName_Test1" -FileSizeMB 120 -Files 5
```
The files will use the name "ComputerName_Test1_FileNumber_TimeStamp.pcap"
Files size will be 120 MB and it will create a maximum of 5 files.

* Trace only traffic going to port 8080
```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -CaptureFilter "Port 8080"
```

* Trace and copress the results to C:\WireSharkTrace\ComputerName_Date_Time.zip 
```PowerShell
.\Trace-WireSharkSelectedNICs.ps1 -TracePath C:\WireSharkTrace -Compress
```
