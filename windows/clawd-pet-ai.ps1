# Make fresh pet chats about today's Korean search trends with Claude, for the pets to use.
# Writes %LOCALAPPDATA%\clawd-pet\ai-<ticks>.txt (A:/B: lines, blank line between chats).
$dir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'clawd-pet'
[void][IO.Directory]::CreateDirectory($dir)
$lock = Join-Path $dir 'ai-running'
[IO.File]::WriteAllText($lock, '')
try {
  $raw = (Invoke-WebRequest -UseBasicParsing 'https://storage.googleapis.com/benyco-trends-kr/data/search-000000000000.json').RawContentStream.ToArray()
  $data = [Text.Encoding]::UTF8.GetString($raw) | ConvertFrom-Json
  $day = $data.days | Sort-Object date | Select-Object -Last 1
  $topics = $day.terms | Select-Object -First 20 | Get-Random -Count 8 |
    ForEach-Object { "- $($_.term): $($_.who) / $($_.why)" }

  $prompt = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'clawd-pet-ai-prompt.txt'), [Text.Encoding]::UTF8) + ($topics -join "`n")
  # hooks off so this run doesn't trigger the "done" announcement; settings via file (PS 5.1 mangles quoted args)
  $settings = Join-Path $dir 'ai-settings.json'
  [IO.File]::WriteAllText($settings, '{"disableAllHooks": true}')
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
  $OutputEncoding = New-Object Text.UTF8Encoding $false
  Push-Location $dir
  # topics are outside text: no tools or MCP servers, so it can only write text ('""' = empty arg in PS 5.1)
  $out = $prompt | & claude -p --model haiku --max-turns 1 --no-session-persistence --settings $settings --tools '""' --strict-mcp-config
  Pop-Location

  $chat = ($out | Where-Object { $_ -match '^\s*[AB]\s*:\s*\S' -or $_.Trim() -eq '' }) -join "`n"
  $chat = $chat -replace '[\uD800-\uDFFF\u2600-\u27BF\uFE0F]', ''  # the bubble font can't draw emoji
  if ($chat -match '[AB]\s*:') {
    $file = Join-Path $dir "ai-$([DateTime]::UtcNow.Ticks).txt"
    [IO.File]::WriteAllText("$file.tmp", $chat.Trim() + "`n", [Text.Encoding]::UTF8)
    Move-Item "$file.tmp" $file -Force
  }
} finally {
  Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
