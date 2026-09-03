$agents = Get-ChildItem ".opencode\agents\*.md"
$declared = foreach ($agent in $agents) {
  $model = Select-String -Path $agent.FullName -Pattern '^model:\s*(\S+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
  [PSCustomObject]@{ Agent = $agent.BaseName; Model = $model }
}
$available = (opencode models opencode-go) -split "\n"

$missing = $declared | Where-Object { $_ -and $available -notcontains $_.Model }
if ($missing) {
  $missing | ForEach-Object { Write-Host "MISSING: $($_.Agent) -> $($_.Model)" }
  Write-Host "`nVerifica el provider o cambia el model del agente. (opencode no tiene fallback por agente.)"
  exit 1
} else {
  $declared | ForEach-Object { Write-Host "OK: $($_.Agent) -> $($_.Model)" }
  Write-Host "`nTodos los modelos estan disponibles."
}