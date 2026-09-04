$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
  Write-Host "opencode no esta en PATH. Instala opencode o ajusta el PATH y reintenta."
  exit 1
}

$fail = $false
$errors = @()

$effective = @{}
$agents = Get-ChildItem ".opencode\agents\*.md"
foreach ($agent in $agents) {
  $raw = Get-Content $agent.FullName -Raw
  if ($raw -notmatch '(?s)^---\s*\n(.*?)\n---') {
    $errors += "$($agent.BaseName): sin frontmatter valido (--- ... ---)"
    $fail = $true
    continue
  }
  $fm = $Matches[1]
  $name = $agent.BaseName

  $desc = if ($fm -match '(?m)^description:\s*(.+)$') { $Matches[1].Trim() } else { $null }
  $mode = if ($fm -match '(?m)^mode:\s*(\S+)$') { $Matches[1] } else { $null }
  $model = if ($fm -match '(?m)^model:\s*(\S+)$') { $Matches[1] } else { $null }
  $taskAllow = ($fm -match '(?m)^\s*task:\s*allow\s*$')

  if (-not $desc) { $errors += "${name}: falta 'description'"; $fail = $true }
  if ($mode -notin @("primary", "subagent")) { $errors += "${name}: mode invalido ('$mode')"; $fail = $true }
  if ($taskAllow -and $mode -eq "subagent") { $errors += "${name}: un subagent no puede tener 'task: allow'"; $fail = $true }

  if (-not $model) {
    $errors += "${name}: falta 'model' (obligatorio en cada agente)"; $fail = $true
  } elseif ($model -notmatch '^[^/]+/[^/]+$') {
    $errors += "${name}: model mal formado ('$model')"; $fail = $true
  } else {
    $effective[$name] = $model
  }
}

# disponibilidad: si el provider no responde (CI sin credenciales), se omite y avisa
$providers = $effective.Values | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique
$available = @{}
foreach ($p in $providers) {
  $out = $null
  try { $out = & opencode models $p 2>$null } catch {
    Write-Host "WARN: provider '$p' no consultable ($($_.Exception.Message)). Se omite su verificacion."
  }
  if (-not $out) {
    $available[$p] = $null
  } else {
    $available[$p] = @($out -split "\n")
  }
}

foreach ($name in ($effective.Keys | Sort-Object)) {
  $m = $effective[$name]
  $list = $available[($m -split '/')[0]]
  if ($null -eq $list) { continue }
  if ($list -notcontains $m) {
    $errors += "MISSING: $name -> $m"
    $fail = $true
  }
}

if ($errors) {
  $errors | ForEach-Object { Write-Host $_ }
  Write-Host "`nCorrige los errores antes de continuar. (opencode no tiene fallback de modelo por agente.)"
  exit 1
} else {
  $effective.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host "OK: $($_.Key) -> $($_.Value)" }
  Write-Host "`nTodos los agentes y modelos estan validos."
}