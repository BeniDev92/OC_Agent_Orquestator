$ErrorActionPreference = "Stop"

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
  Write-Host "opencode no esta en PATH. Instala opencode o ajusta el PATH y reintenta."
  exit 1
}

$agents = Get-ChildItem ".opencode\agents\*.md"
$declared = foreach ($agent in $agents) {
  $model = Select-String -Path $agent.FullName -Pattern '^model:\s*(\S+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
  if ($model) { [PSCustomObject]@{ Agent = $agent.BaseName; Model = $model } }
}

$providers = $declared.Model | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique

$available = @{}
foreach ($p in $providers) {
  $out = (opencode models $p) 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $out) {
    Write-Host "No se pudo consultar el provider '$p'. Verifica su configuracion."
    exit 1
  }
  $available[$p] = @($out -split "\n")
}

$missing = $declared | Where-Object { $available[($_.Model -split '/')[0]] -notcontains $_.Model }
if ($missing) {
  $missing | ForEach-Object { Write-Host "MISSING: $($_.Agent) -> $($_.Model)" }
  Write-Host "`nVerifica el provider o cambia el model del agente. (opencode no tiene fallback por agente.)"
  exit 1
} else {
  $declared | ForEach-Object { Write-Host "OK: $($_.Agent) -> $($_.Model)" }
  Write-Host "`nTodos los modelos estan disponibles."
}