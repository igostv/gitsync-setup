$utf8 = [System.Text.Encoding]::UTF8
$OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
chcp 65001 > $null

. "$PSScriptRoot\env.ps1"

$gitsync = Join-Path $PSScriptRoot 'oscript_modules\bin\gitsync.bat'
$env:GITSYNC_PLUGINS_PATH = Join-Path $PSScriptRoot 'oscript_modules'

if (-not (Test-Path -LiteralPath $gitsync)) {
    throw 'Local gitsync is not installed. Run: .\setup-gitsync.ps1'
}

& $gitsync sync -i --error-comment --push --push-n-commits 1 $env:GITSYNC_STORAGE_PATH $env:GITSYNC_WORKDIR

if ($LASTEXITCODE -ne 0) {
    throw "gitsync failed with exit code $LASTEXITCODE"
}
