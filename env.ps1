$env:LOGOS_CONFIG = 'logger.rootLogger=INFO'

$env:GITSYNC_STORAGE_PATH = ''  # tcp://host/repo
$env:GITSYNC_STORAGE_USER = ''
$env:GITSYNC_STORAGE_PASSWORD = ''

$env:GITSYNC_WORKDIR = Join-Path $PSScriptRoot 'src/cf'
# $env:GITSYNC_PROJECT_NAME = ''

$env:GITSYNC_V8VERSION = ''  # например, 8.3.27.1989
# $env:GITSYNC_V8_PATH = 'C:\Program Files\1cv8\8.3.xx.xxxx\bin\1cv8.exe'

# $env:GITSYNC_VERBOSE = 'true'
# $env:GITSYNC_TEMP = Join-Path $PSScriptRoot 'temp\gitsync'

if ([string]::IsNullOrWhiteSpace($env:GITSYNC_STORAGE_PATH)) {
    throw 'GITSYNC_STORAGE_PATH is not set. Fill it in env.ps1.'
}

if ([string]::IsNullOrWhiteSpace($env:GITSYNC_STORAGE_USER)) {
    throw 'GITSYNC_STORAGE_USER is not set. Fill it in env.ps1.'
}


