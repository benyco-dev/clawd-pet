# Desktop pet: walks on window tops and the taskbar. Drag to move, right-click to quit.
# -Pet clawd | white | black
param([string]$Pet = 'clawd')
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class Floor {
  public struct RECT { public int L, T, R, B; }
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);

  // Highest visible window top edge at column x, at or below feet; fallback = taskbar.
  // tol: how far above the feet a top edge may be and still count (snaps the pet up onto it).
  public static IntPtr Hit;  // window the last Find landed on (Zero = taskbar)
  static List<RECT> rects = new List<RECT>();  // z-order, topmost first
  static List<IntPtr> hs = new List<IntPtr>();
  static void Scan(IntPtr self) {
    rects.Clear(); hs.Clear();
    EnumWindows((h, p) => {
      if (h == self || !IsWindowVisible(h) || IsIconic(h) || GetWindowTextLength(h) == 0) return true;
      if ((GetWindowLong(h, -20) & 0x80) != 0) return true;  // WS_EX_TOOLWINDOW
      int cloaked; if (DwmGetWindowAttribute(h, 14, out cloaked, 4) == 0 && cloaked != 0) return true;
      RECT r; if (DwmGetWindowAttribute(h, 9, out r, 16) != 0) return true;  // visible frame bounds
      if (r.R > r.L && r.B > r.T) { rects.Add(r); hs.Add(h); }
      return true;
    }, IntPtr.Zero);
  }

  public static int Find(int x, int feet, int fallback, IntPtr self, int tol) {
    Scan(self);
    int best = fallback;
    Hit = IntPtr.Zero;
    for (int i = 0; i < rects.Count; i++) {
      var r = rects[i];
      if (x < r.L || x >= r.R || r.T < feet - tol || r.T >= best) continue;
      bool hidden = false;
      for (int j = 0; j < i; j++) { var o = rects[j]; if (x >= o.L && x < o.R && r.T >= o.T && r.T < o.B) { hidden = true; break; } }
      if (!hidden) { best = r.T; Hit = hs[i]; }
    }
    return best;
  }

  // Topmost window containing the point, or Zero.
  public static IntPtr At(int x, int y, IntPtr self) {
    Scan(self);
    for (int i = 0; i < rects.Count; i++) { var r = rects[i]; if (x >= r.L && x < r.R && y >= r.T && y < r.B) return hs[i]; }
    return IntPtr.Zero;
  }

  // Current left/top/right of a window; false if it closed, hid or minimized.
  public static bool Pos(IntPtr h, out int l, out int t, out int rt) {
    l = t = rt = 0; RECT r;
    if (!IsWindowVisible(h) || IsIconic(h) || DwmGetWindowAttribute(h, 9, out r, 16) != 0) return false;
    l = r.L; t = r.T; rt = r.R; return true;
  }
}
"@
[Floor]::SetProcessDPIAware() | Out-Null

# Big head, small body. H = eye highlight, D = lower eye row, B = blush.
$kitten = @(
  ".......K......K.",
  "......KPK....KPK",
  ".K....KWPKKKKPWK",
  "KWK...KWWWWWWWWK",
  "KWK...KWHEWWHEWK",
  "KWK...KWDDWWDDWK",
  ".KWKKKKBWWPPWWBK",
  "..KWWWWWWWWWWWK.",
  "..KWWWWWWWWWWWK."
)
$kittenLegs = @(@("..KWKWK..KWKWK..", "..KKKKK..KKKKK.."), @(".KWK.KWKWK.KWK..", ".KKK.KKKKK.KKK.."))
$kittenSit = @(
  "................",
  "................",
  ".......K......K.",
  "......KPK....KPK",
  "......KWPKKKKPWK",
  "...KKKKWWWWWWWWK",
  "..KWWWKWHEWWHEWK",
  "..KWWWKWDDWWDDWK",
  ".KWWWWKBWWPPWWBK",
  "KKKKWWWWWWWWWWK.",
  "KWWWKKKKKKKKKKK."
)
# Picked up: "!" (X), ring eyes with pupils (S), open mouth (M).
$kittenDrag = @(
  "....X..K......K.",
  "....X.KPK....KPK",
  ".K..X.KWPKKKKPWK",
  "KWK...KWWWWWWWWK",
  "KWK.X.KDDDWWDDDK",
  "KWK...KDSDWWDSDK",
  ".KWKKKKDDDPPDDDK",
  "..KWWWWWWWMMWWK.",
  "..KWWWWWWWWWWWK.",
  "..KWKWK..KWKWK..",
  "..KKKKK..KKKKK.."
)
$blinkMap = @{ H = 'W'; E = 'W'; D = 'K' }
$kittenSay = 0xC791, 0xC5C5, 0x20, 0xC644, 0xB8CC, 0xB0E5, 0x21  # "done, meow!"
$sprites = @{
  # Say: bubble text as code points (keeps this file ASCII for PowerShell 5.1)
  clawd = @{ Px = 10; Flip = $false; Legs = @(@("...#...#....."), @(".....#...#..."))
    Say = 0xC791, 0xC5C5, 0x20, 0xC644, 0xB8CC, 0x21
    Drag = @("#.#########.#", "#.##o###o##.#", "#############", "..#########..", "...#.#.#.#...", "...#.#.#.#...")
    Body = @("..#########..", "..##o###o##..", "#############", "..#########..", "...#.#.#.#...")
    Colors = @{ '#' = 217, 119, 87; 'o' = 0, 0, 0 } }
  white = @{ Px = 6; Flip = $true; Body = $kitten; Legs = $kittenLegs; Sit = $kittenSit; Drag = $kittenDrag; Say = $kittenSay
    Colors = @{ K = 70, 70, 70; W = 252, 252, 252; E = 40, 40, 40; D = 40, 40, 40; H = 255, 255, 255; P = 245, 150, 175; B = 255, 195, 210
      X = 230, 60, 60; S = 255, 255, 255; M = 90, 40, 45 } }
  black = @{ Px = 6; Flip = $true; Body = $kitten; Legs = $kittenLegs; Sit = $kittenSit; Drag = $kittenDrag; Say = $kittenSay
    Colors = @{ K = 10, 10, 10; W = 45, 45, 45; E = 250, 205, 40; D = 250, 205, 40; H = 255, 255, 255; P = 230, 130, 155; B = 150, 70, 90
      X = 230, 60, 60; S = 10, 10, 10; M = 170, 60, 80 } }
}
$sp = $sprites[$Pet]
if (-not $sp) { throw "Unknown pet '$Pet'. Use: $($sprites.Keys -join ', ')" }
$brushes = @{}
foreach ($ch in $sp.Colors.Keys) { $c = $sp.Colors[$ch]; $brushes[$ch] = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($c[0], $c[1], $c[2])) }

$k = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero).DpiX / 96
$px = [int]($sp.Px * $k)
$cols = $sp.Body[0].Length
$rowCount = $sp.Body.Count + $sp.Legs[0].Count

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.StartPosition = 'Manual'
$form.BackColor = [System.Drawing.Color]::Magenta
$form.TransparencyKey = [System.Drawing.Color]::Magenta
$form.ClientSize = New-Object System.Drawing.Size ($cols * $px), ($rowCount * $px)
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($form, $true, $null)

$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:x = Get-Random -Minimum $area.Left -Maximum ($area.Right - $form.Width)
$script:y = $area.Bottom - $form.Height
$script:dx = 4 * $k * (Get-Random -InputObject 1, -1)
$script:vy = 0
$script:t = 0
$script:blink = 0
$script:rest = 0
$script:on = [IntPtr]::Zero  # window we're standing on
$script:onL = 0; $script:onT = 0
$script:perch = -1  # > 0: standing this far below the top of window $on (its top is off-screen)
$script:drag = $false
$form.Location = New-Object System.Drawing.Point ([int]$script:x), ([int]$script:y)

# Speech bubble for "Claude finished" (signal file written by clawd-pet-notify.ps1).
$bubble = New-Object System.Windows.Forms.Form
$bubble.FormBorderStyle = 'None'
$bubble.TopMost = $true
$bubble.ShowInTaskbar = $false
$bubble.StartPosition = 'Manual'
$bubble.AutoSize = $true
$bubble.AutoSizeMode = 'GrowAndShrink'
$label = New-Object System.Windows.Forms.Label
$label.Text = -join [char[]]$sp.Say
$label.AutoSize = $true
$label.Font = New-Object System.Drawing.Font('Malgun Gothic', 11, [System.Drawing.FontStyle]::Bold)
$label.Padding = New-Object System.Windows.Forms.Padding 8, 4, 8, 4
$label.BorderStyle = 'FixedSingle'
$label.BackColor = [System.Drawing.Color]::White
$bubble.Controls.Add($label)
$null = $bubble.Handle
$signal = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'clawd-pet-done.txt'
$script:sigTime = [IO.File]::GetLastWriteTimeUtc($signal)  # ignore signals from before startup
$script:say = 0

function SayTicks($text) { 30 + 2 * $text.Length }  # 80 ms ticks: ~2.4 s + a bit per character
function Say($text) {
  $label.Text = $text
  $n = SayTicks $text
  $script:say = $n
  [Floor]::ShowWindow($bubble.Handle, 4) | Out-Null  # SW_SHOWNOACTIVATE: don't steal focus
  if (-not $script:drag) { $script:rest = [math]::Max($script:rest, $n) }  # stop to talk
}

# --- Talking: time-of-day lines to you, and chats between pets (lines from clawd-pet-lines.txt) ---
# The pet holding the mutex is the director: it picks who says what and writes events.txt;
# every pet shows its own lines from there. Pets touch alive-<name> so the director knows who's around.
$dir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'clawd-pet'
[void][IO.Directory]::CreateDirectory($dir)
$events = Join-Path $dir 'events.txt'
$script:evTime = [IO.File]::GetLastWriteTimeUtc($events)
$script:queue = New-Object System.Collections.ArrayList  # @{ Due = UTC ticks; Text }
$mutex = New-Object System.Threading.Mutex($false, 'Local\clawd-pet-director')
$script:leader = $false
$script:n = 0

# [h-h] = lines to you in that hour range (first = greeting); any other [..] = chats (A:/B:, blank line between)
$slots = @(); $chats = @(); $chat = @(); $mode = ''
$linesPath = Join-Path $PSScriptRoot 'clawd-pet-lines.txt'
if (Test-Path $linesPath) {
  foreach ($raw in [IO.File]::ReadAllLines($linesPath, [Text.Encoding]::UTF8)) {
    $ln = $raw.Trim()  # not $t: that's the walk-animation counter at script scope
    if ($ln -eq '' -or $ln.StartsWith('#')) { if ($chat.Count) { $chats += , $chat; $chat = @() }; continue }
    if ($ln -match '^\[(\d+)-(\d+)\]$') { $cur = @{ From = [int]$Matches[1]; To = [int]$Matches[2]; Lines = New-Object System.Collections.ArrayList }; $slots += $cur; $mode = 'slot' }
    elseif ($ln -match '^\[.*\]$') { $mode = 'chat' }
    elseif ($mode -eq 'slot') { [void]$cur.Lines.Add($ln) }
    elseif ($mode -eq 'chat' -and $ln -match '^([AB])\s*:\s*(.+)$') { $chat += , @($Matches[1], $Matches[2]) }
  }
  if ($chat.Count) { $chats += , $chat }
}

# items: @(speaker, text[, listener]) spoken one after another
function Emit($items) {
  $start = [DateTime]::UtcNow.Ticks; $off = 0
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine($start)
  foreach ($it in $items) {
    [void]$sb.AppendLine("$off`t$($it[0])`t$($it[1])`t$($it[2])")
    $off += ((SayTicks $it[1]) * 80 + 400) * 10000
  }
  [IO.File]::WriteAllText("$events.tmp", $sb.ToString(), [Text.Encoding]::UTF8)
  Move-Item "$events.tmp" $events -Force
  $script:busyUntil = [DateTime]::UtcNow.AddTicks($off + 20000000)
}

# AI chats about today's trends: clawd-pet-ai.ps1 drops ai-*.txt files (A:/B: lines, blank line between chats)
$aiScript = Join-Path $PSScriptRoot 'clawd-pet-ai.ps1'
$script:nextGen = [DateTime]::MinValue
function AiFiles { Get-ChildItem $dir -Filter 'ai-*.txt' | Where-Object { $_.Extension -eq '.txt' } | Sort-Object Name }
function AiBlocks($file) { @(([IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) -replace "`r", '') -split "`n\s*`n" | Where-Object { $_.Trim() }) }

# Take (and remove) the oldest AI chat as @(role, text) pairs, or $null.
function TakeAiChat {
  $f = AiFiles | Select-Object -First 1
  if (-not $f) { return $null }
  $blocks = AiBlocks $f
  if ($blocks.Count -gt 1) { [IO.File]::WriteAllText($f.FullName, (($blocks | Select-Object -Skip 1) -join "`n`n") + "`n", [Text.Encoding]::UTF8) }
  else { Remove-Item $f.FullName -Force }
  $chat = @()
  foreach ($l in (@($blocks)[0] -split "`n")) { if ($l -match '^\s*([AB])\s*:\s*(.+)$') { $chat += , @($Matches[1], $Matches[2].Trim()) } }
  if ($chat.Count) { return , $chat }
  return $null
}

# Keep a few AI chats in stock; generating takes ~1 min in the background.
function RefillAi {
  $utc = [DateTime]::UtcNow
  if ($utc -lt $script:nextGen -or -not (Test-Path $aiScript)) { return }
  $lock = Join-Path $dir 'ai-running'
  if ((Test-Path $lock) -and (Get-Item $lock).LastWriteTimeUtc -gt $utc.AddMinutes(-5)) { return }
  $stock = 0; foreach ($f in AiFiles) { $stock += (AiBlocks $f).Count }
  if ($stock -ge 3) { return }
  $script:nextGen = $utc.AddMinutes(10)  # at most one Claude call per 10 min
  Start-Process powershell -WindowStyle Hidden -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$aiScript`""
}

function Direct {
  $utc = [DateTime]::UtcNow
  RefillAi
  if ($utc -lt $script:busyUntil) { return }
  $cut = $utc.AddSeconds(-10)
  $alive = @(Get-ChildItem $dir -Filter 'alive-*' | Where-Object { $_.LastWriteTimeUtc -gt $cut } | ForEach-Object { $_.Name.Substring(6) })
  if ($alive.Count -eq 0) { return }
  $now = Get-Date; $h = $now.Hour
  $slot = $slots | Where-Object { if ($_.From -lt $_.To) { $h -ge $_.From -and $h -lt $_.To } else { $h -ge $_.From -or $h -lt $_.To } } | Select-Object -First 1
  if ($slot -and $slot.Lines.Count) {
    # greet once when a time slot starts (or when pets start during it)
    $day = if ($slot.From -gt $slot.To -and $h -lt $slot.To) { $now.AddDays(-1) } else { $now }  # overnight slot started yesterday
    $key = '{0:yyyyMMdd}-{1}' -f $day, $slot.From
    $gf = Join-Path $dir 'greeted.txt'
    if ("$(Get-Content $gf -ErrorAction SilentlyContinue)" -ne $key) {
      Set-Content $gf $key
      Emit @(, @((Get-Random -InputObject $alive), $slot.Lines[0])); return
    }
    if ($utc -gt $script:nextRemark) {
      $script:nextRemark = $utc.AddMinutes((Get-Random -Minimum 3.0 -Maximum 5.0))
      Emit @(, @((Get-Random -InputObject $alive), (Get-Random -InputObject @($slot.Lines)))); return
    }
  }
  if ($alive.Count -ge 2 -and $utc -gt $script:nextChat) {
    # half the time an AI chat about today's trends, otherwise one from the lines file
    $c = $null
    if ((Get-Random -Maximum 2) -eq 0) { $c = TakeAiChat }
    if (-not $c -and $chats.Count) { $c = $chats[(Get-Random -Maximum $chats.Count)] }
    if (-not $c) { return }
    $script:nextChat = $utc.AddMinutes((Get-Random -Minimum 1.0 -Maximum 2.0))
    $pair = @($alive | Get-Random -Count 2)
    Emit @($c | ForEach-Object { if ($_[0] -eq 'A') { , @($pair[0], $_[1], $pair[1]) } else { , @($pair[1], $_[1], $pair[0]) } })
  }
}

$form.Add_Paint({
  param($s, $e)
  $rows = if ($script:drag -and $sp.Drag) { $sp.Drag } elseif ($script:rest -gt 0 -and $sp.Sit) { $sp.Sit } else { $sp.Body + $sp.Legs[[int][math]::Floor($script:t / 3) % $sp.Legs.Count] }
  $mirror = $sp.Flip -and $script:dx -lt 0  # sprites face right
  for ($r = 0; $r -lt $rows.Count; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
      $ch = [string]$rows[$r][$c]
      if ($script:blink -gt 0 -and $blinkMap[$ch]) { $ch = $blinkMap[$ch] }
      $b = $brushes[$ch]
      if ($b) { $e.Graphics.FillRectangle($b, $(if ($mirror) { $cols - 1 - $c } else { $c }) * $px, $r * $px, $px, $px) }
    }
  }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 80
$timer.Add_Tick({
  # re-read the screen every tick so a resolution/taskbar change can't strand pets off-screen
  # (the floor falls back to the new bottom, which pulls a pet below it back up)
  $script:area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $w = [IO.File]::GetLastWriteTimeUtc($signal)
  if ($w -ne $script:sigTime) {
    $script:sigTime = $w
    $who = "$(Get-Content $signal -Raw -ErrorAction SilentlyContinue)".Split(' ')[0]
    if ($who -eq $Pet) {
      Say (-join [char[]]$sp.Say)
      if (-not $script:drag) { $script:rest = 0; $script:y -= 1; $script:vy = -10 * $k }  # happy hop
    }
  }
  # talking: heartbeat, director election, and this pet's lines from events.txt
  $script:n++
  if ($script:n % 12 -eq 1) { [IO.File]::WriteAllText((Join-Path $dir "alive-$Pet"), "$([int]($script:x + $form.Width / 2))") }  # heartbeat + center x
  if (-not $script:leader -and $script:n % 60 -eq 1) {
    try { $script:leader = $mutex.WaitOne(0) } catch { $script:leader = $true }  # abandoned mutex = ours now
    if ($script:leader) {
      $script:busyUntil = [DateTime]::UtcNow.AddSeconds(15)  # let pets land first
      $script:nextChat = [DateTime]::UtcNow.AddMinutes((Get-Random -Minimum 0.5 -Maximum 1.0))
      $script:nextRemark = [DateTime]::UtcNow.AddMinutes((Get-Random -Minimum 2.0 -Maximum 3.0))
    }
  }
  if ($script:leader -and $script:n % 12 -eq 0) { Direct }
  $w = [IO.File]::GetLastWriteTimeUtc($events)
  if ($w -ne $script:evTime) {
    $script:evTime = $w
    try {
      $ls = [IO.File]::ReadAllLines($events, [Text.Encoding]::UTF8)
      $start = [long]$ls[0]; $end = $start; $other = $null
      for ($i = 1; $i -lt $ls.Count; $i++) {
        $f = $ls[$i].Split("`t")
        if ($f.Count -lt 3) { continue }
        $due = $start + [long]$f[0]
        $lineEnd = $due + (SayTicks $f[2]) * 800000
        if ($f[1] -eq $Pet) {
          [void]$script:queue.Add(@{ Due = $due; Text = $f[2] })
          if ($f.Count -ge 4 -and $f[3]) { $other = $f[3]; $end = [math]::Max($end, $lineEnd) }
        } elseif ($f.Count -ge 4 -and $f[3] -eq $Pet) { $other = $f[1]; $end = [math]::Max($end, $lineEnd) }
      }
      if ($other) {
        # in a chat: face the other pet and stay put until it's over
        $ox = "$(Get-Content (Join-Path $dir "alive-$other") -ErrorAction SilentlyContinue)"
        if ($ox -match '^-?\d+$') { $script:dx = [math]::Abs($script:dx) * $(if ([int]$ox -ge $script:x + $form.Width / 2) { 1 } else { -1 }) }
        if (-not $script:drag) { $script:rest = [math]::Max($script:rest, [int](($end - [DateTime]::UtcNow.Ticks) / 800000) + 5) }
      }
    } catch {}  # mid-replace; the next tick sees the new file
  }
  if ($script:queue.Count -and $script:queue[0].Due -le [DateTime]::UtcNow.Ticks) { Say $script:queue[0].Text; $script:queue.RemoveAt(0) }
  if ($script:say -gt 0) {
    $script:say--
    $bx = [math]::Max($area.Left, [math]::Min($area.Right - $bubble.Width, $form.Left + ($form.Width - $bubble.Width) / 2))
    $bubble.Location = New-Object System.Drawing.Point ([int]$bx), ([int]($form.Top - $bubble.Height - 4))
    if ($script:say -eq 0) { [Floor]::ShowWindow($bubble.Handle, 0) | Out-Null }
  }
  if ($script:drag) { return }
  if ($script:blink -gt 0) { $script:blink-- } elseif ((Get-Random -Maximum 50) -eq 0) { $script:blink = 2 }
  # ride along if the window we stand on moved
  $l = 0; $tp = 0; $rt = 0
  if ($script:on -ne [IntPtr]::Zero -and [Floor]::Pos($script:on, [ref]$l, [ref]$tp, [ref]$rt)) {
    $script:x += $l - $script:onL
    $script:y += $tp - $script:onT
  }
  $h = $form.Height
  $cx = [int]($script:x + $form.Width / 2)
  # standing on a window: keep its top (or the perch height) as the floor even if other windows
  # cover it, until the window closes/minimizes or we leave its sides
  $floor = $null
  $hit = $script:on
  if ($script:on -ne [IntPtr]::Zero) {
    if ([Floor]::Pos($script:on, [ref]$l, [ref]$tp, [ref]$rt) -and $cx -ge $l -and $cx -lt $rt) { $floor = $tp + [math]::Max($script:perch, 0) }
    else { $script:on = [IntPtr]::Zero; $script:perch = -1 }
  }
  if ($null -eq $floor) {
    $floor = [Floor]::Find($cx, [int]($script:y + $h), $area.Bottom, $form.Handle, [int](4 * $k))
    $hit = [Floor]::Hit
  }
  if ($script:y + $h -lt $floor) {
    # falling (or hopping)
    $script:vy = [math]::Min($script:vy + 2 * $k, 40 * $k)
    $script:y = [math]::Min($script:y + $script:vy, $floor - $h)
  } else {
    $script:vy = 0
    $script:y = $floor - $h
    $script:on = $hit
    if ([Floor]::Pos($script:on, [ref]$l, [ref]$tp, [ref]$rt)) { $script:onL = $l; $script:onT = $tp }
    if ($script:rest -gt 0) {
      $script:rest--
    } elseif ((Get-Random -Maximum 150) -eq 0) {
      $script:rest = Get-Random -Minimum 40 -Maximum 100  # sit 3-8 s
    } elseif ((Get-Random -Maximum 300) -eq 0) {
      $script:y -= 1; $script:vy = -10 * $k  # hop now and then (~every 25 s of walking)
    } else {
      $script:t++
      $script:x += $script:dx
      # turn around at the edges of the window we're on, and of the screen
      $minX = $area.Left; $maxX = $area.Right
      if ($script:on -ne [IntPtr]::Zero -and [Floor]::Pos($script:on, [ref]$l, [ref]$tp, [ref]$rt) -and $rt - $l -gt $form.Width) {
        $minX = [math]::Max($minX, $l); $maxX = [math]::Min($maxX, $rt)
      }
      if ($script:x -lt $minX) { $script:dx = [math]::Abs($script:dx); $script:x = $minX }
      elseif ($script:x + $form.Width -gt $maxX) { $script:dx = -[math]::Abs($script:dx); $script:x = $maxX - $form.Width }
    }
  }
  $form.Location = New-Object System.Drawing.Point ([int]$script:x), ([int]$script:y)
  $form.Invalidate()
})

$form.Add_MouseDown({ param($s, $e) if ($e.Button -eq 'Left') { $script:drag = $true; $script:on = [IntPtr]::Zero; $script:perch = -1; $script:rest = 0; $script:blink = 0; $script:grab = $e.Location; $form.Invalidate() } })
$form.Add_MouseMove({
  if ($script:drag) {
    $p = [System.Windows.Forms.Cursor]::Position
    $script:x = $p.X - $script:grab.X
    $script:y = $p.Y - $script:grab.Y
    $form.Location = New-Object System.Drawing.Point ([int]$script:x), ([int]$script:y)
  }
})
$form.Add_MouseUp({
  param($s, $e)
  if ($e.Button -eq 'Right') { $form.Close(); return }
  $script:drag = $false
  $script:vy = 0
  $h = $form.Height
  $cx = [int]($script:x + $form.Width / 2)
  $feet = [int]($script:y + $h)
  $f = [Floor]::Find($cx, $feet, $area.Bottom, $form.Handle, $h)
  if ($f -le $feet) {
    # feet on/overlapping a title bar: stand on its top edge
    $script:y = $f - $h; $form.Top = [int]$script:y
  } else {
    # dropped over a window's body: climb onto its top edge (kept on-screen for maximized windows)
    $hw = [Floor]::At($cx, $feet - 1, $form.Handle)
    $l = 0; $tp = 0; $rt = 0
    if ($hw -ne [IntPtr]::Zero -and [Floor]::Pos($hw, [ref]$l, [ref]$tp, [ref]$rt)) {
      $script:on = $hw; $script:onL = $l; $script:onT = $tp
      $script:perch = [math]::Max(0, $area.Top + $h - $tp)
      $script:y = $tp + $script:perch - $h; $form.Top = [int]$script:y
    }
  }
  $form.Invalidate()
})
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
