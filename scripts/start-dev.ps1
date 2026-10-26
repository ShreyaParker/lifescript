param([switch]$Restart)
$ErrorActionPreference = 'Stop'
$lifeRoot = Split-Path -Parent $PSScriptRoot
$lifeBackend = Join-Path $lifeRoot 'backend'
$lifePython = Join-Path $lifeBackend 'venv\Scripts\python.exe'
$lifeLogs = Join-Path $lifeBackend '.local'
if (-not (Test-Path -LiteralPath $lifePython)) { throw 'Set up backend/venv first.' }
if (-not (Test-Path -LiteralPath (Join-Path $lifeRoot 'frontend\build\web\index.html'))) { throw 'Build Flutter web first.' }
New-Item -ItemType Directory -Path $lifeLogs -Force | Out-Null
if ($Restart) {
    $lifePrefixes = @('uvicorn app.main:app', 'app.worker', 'http.server 8080', 'app.serve_web')
    Get-CimInstance Win32_Process | Where-Object {
        $candidate = $_
        $candidate.Name -match '^python(w)?\.exe$' -and
        @($lifePrefixes | Where-Object { $candidate.CommandLine.StartsWith('"' + $lifePython + '" -m ' + $_) }).Count -gt 0
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
}
foreach ($lifeService in @(
    @{Name='api'; Args=@('-m','uvicorn','app.main:app','--host','127.0.0.1','--port','8000','--no-access-log')},
    @{Name='worker'; Args=@('-m','app.worker')},
    @{Name='web'; Args=@('-m','app.serve_web')}
)) {
    $lifeProcess = Start-Process -FilePath $lifePython -ArgumentList $lifeService.Args -WorkingDirectory $lifeBackend -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $lifeLogs ($lifeService.Name + '.stdout.log')) `
        -RedirectStandardError (Join-Path $lifeLogs ($lifeService.Name + '.stderr.log'))
    Write-Output ($lifeService.Name + ' launched (PID ' + $lifeProcess.Id + ')')
}
Write-Output 'Web: http://127.0.0.1:8080 | API readiness: http://127.0.0.1:8000/health/ready'
