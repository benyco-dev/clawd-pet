# Start every desktop pet that isn't already running.
$running = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*clawd-pet.ps1*' } |
  ForEach-Object { if ($_.CommandLine -match '-Pet\s+(\w+)') { $Matches[1] } else { 'clawd' } }
foreach ($p in 'clawd', 'white', 'black') {
  if ($running -notcontains $p) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\clawd-pet.ps1`" -Pet $p"
  }
}
