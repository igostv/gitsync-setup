$utf8 = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
chcp 65001 | Out-Null

$settingsFile = Join-Path $PSScriptRoot '.vrunner.json'
if (-not (Test-Path $settingsFile)) {
    throw ".vrunner.json не найден в $PSScriptRoot. Скопируйте .vrunner.json.example и заполните настройки."
}
$s = Get-Content $settingsFile -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($s.connection)) {
    throw 'connection не задан в .vrunner.json'
}
if ([string]::IsNullOrWhiteSpace($s.'db-user')) {
    throw 'db-user не задан в .vrunner.json'
}

$env:LOGOS_CONFIG             = 'logger.rootLogger=INFO'
$env:GITSYNC_STORAGE_PATH     = $s.connection
$env:GITSYNC_STORAGE_USER     = $s.'db-user'
$env:GITSYNC_STORAGE_PASSWORD = $s.'db-pwd'
$env:GITSYNC_WORKDIR          = if ($s.'gitsync-workdir') {
                                    Join-Path $PSScriptRoot $s.'gitsync-workdir'
                                } else {
                                    Join-Path $PSScriptRoot 'src/cf'
                                }
if ($s.'v8version') { $env:GITSYNC_V8VERSION = $s.'v8version' }
if ($s.'v8path')    { $env:GITSYNC_V8_PATH   = $s.'v8path' }

$gitsync = Join-Path $PSScriptRoot 'oscript_modules\bin\gitsync.bat'
$env:GITSYNC_PLUGINS_PATH = Join-Path $PSScriptRoot 'oscript_modules'

if (-not (Test-Path -LiteralPath $gitsync)) {
    throw 'Local gitsync is not installed. Run: .\setup-gitsync.ps1'
}

& $gitsync sync -i --error-comment --push --push-n-commits 1 $env:GITSYNC_STORAGE_PATH $env:GITSYNC_WORKDIR

if ($LASTEXITCODE -ne 0) {
    throw "gitsync failed with exit code $LASTEXITCODE"
}
