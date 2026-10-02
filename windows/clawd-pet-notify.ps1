# Claude Code Stop hook: pick one running desktop pet at random and tell it to announce "done".
$pets = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*clawd-pet.ps1*' } |
  ForEach-Object { if ($_.CommandLine -match '-Pet\s+(\w+)') { $Matches[1] } else { 'clawd' } }
if (-not $pets) { exit 0 }
$pick = Get-Random -InputObject @($pets)
$signal = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'clawd-pet-done.txt'
# write-then-rename so pets polling the file never see it half-written
Set-Content -Path "$signal.tmp" -Value "$pick $([DateTime]::Now.Ticks)" -Encoding ascii
Move-Item -Path "$signal.tmp" -Destination $signal -Force
