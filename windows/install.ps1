# Start the desktop pets now and at every login, add desktop on/off buttons, and hook them to Claude Code.
# Run from this folder (pets run from here, so keep the folder where it is):
#   powershell -ExecutionPolicy Bypass -File install.ps1               (clawd + white + black)
#   powershell -ExecutionPolicy Bypass -File install.ps1 white black   (pick pets)
# This file stays ASCII for PowerShell 5.1; Korean names are written as code points.
$pets = if ($args.Count) { $args } else { 'clawd', 'white', 'black' }
$here = $PSScriptRoot
$sh = New-Object -ComObject WScript.Shell
function Link($path, $script, $extra) {
  $sc = $sh.CreateShortcut($path)
  $sc.TargetPath = 'powershell.exe'
  $sc.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$here\$script`" $extra"
  $sc.WindowStyle = 7  # minimized
  $sc.Save()
}

# Start at login
$startup = [Environment]::GetFolderPath('Startup')
Get-ChildItem $startup -Filter 'clawd-pet-*.lnk' | Remove-Item -Force
foreach ($p in $pets) { Link (Join-Path $startup "clawd-pet-$p.lnk") 'clawd-pet.ps1' "-Pet $p" }

# Desktop buttons: double-click to start/stop all pets
$desk = [Environment]::GetFolderPath('Desktop')
$on = -join [char[]](0xD3AB, 0x20, 0xBAA8, 0xB450, 0x20, 0xCF1C, 0xAE30)   # pets all on
$off = -join [char[]](0xD3AB, 0x20, 0xBAA8, 0xB450, 0x20, 0xB044, 0xAE30)  # pets all off
Link (Join-Path $desk "$on.lnk") 'clawd-pet-start.ps1' ''
Link (Join-Path $desk "$off.lnk") 'clawd-pet-stop.ps1' ''

# Claude Code Stop hook: a random pet says "done" when Claude finishes
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'
$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$($here -replace '\\', '/')/clawd-pet-notify.ps1`""
$s = if (Test-Path $settings) { Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
if (-not $s.hooks) { $s | Add-Member hooks ([pscustomobject]@{}) }
if (-not $s.hooks.Stop) { $s.hooks | Add-Member Stop @() }
if (-not ($s.hooks.Stop | ForEach-Object { $_.hooks } | Where-Object { $_.command -eq $cmd })) {
  if (Test-Path $settings) { Copy-Item $settings "$settings.bak" -Force }  # ConvertTo-Json reformats the file
  $s.hooks.Stop = @($s.hooks.Stop) + [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $cmd; timeout = 15; async = $true }) }
  [void][IO.Directory]::CreateDirectory((Split-Path $settings))
  [IO.File]::WriteAllText($settings, ($s | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
  'Claude Code done hook added (backup: settings.json.bak).'
}

& "$here\clawd-pet-stop.ps1"
foreach ($p in $pets) { Start-Process powershell -WindowStyle Hidden -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$here\clawd-pet.ps1`" -Pet $p" }
'Done! Pets are on the taskbar. Right-click a pet to close it.'
