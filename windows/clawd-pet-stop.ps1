# Close every running desktop pet.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*clawd-pet.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
