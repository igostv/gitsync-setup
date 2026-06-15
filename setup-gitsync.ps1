# setup-gitsync.ps1
# Устанавливает gitsync (с приоритизацией плагинов) и плагин МержВетки
# в указанный каталог проекта.
#
# Использование (из корня целевого проекта):
#   irm https://raw.githubusercontent.com/igostv/gitsync-setup/master/setup-gitsync.ps1 | iex
#
# Или скачать и запустить вручную:
#   .\setup-gitsync.ps1 [-ProjectRoot <путь>] [-UseRegistry]
#
# Параметры:
#   -ProjectRoot  Корень проекта, куда устанавливается gitsync.
#                 По умолчанию — текущий каталог.
#   -UseRegistry  Устанавливать gitsync из hub.oscript.io вместо форка на GitHub.
#                 TODO: включить после того, как PR #364 влит в основной gitsync.
#
# Требования:
#   - opm в PATH (oscript)
#   - git в PATH (при установке из форка)
#   - доступ к github.com по SSH (при установке из форка)

param(
    [string]$ProjectRoot = $PWD.Path,
    [switch]$UseRegistry
)

$ErrorActionPreference = 'Stop'

$GitsyncFork    = 'git@github.com:igostv/gitsync.git'
$GitsyncBranch  = 'feature/plugin-priority-sorting'
$PluginRepo     = 'git@github.com:igostv/gitsync-plugin-merge-branch.git'

function Invoke-Step([string]$Label, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "==> $Label"
    & $Action
}

# ---------------------------------------------------------------------------
# 1. Установка gitsync
# ---------------------------------------------------------------------------
if ($UseRegistry) {
    Invoke-Step "Устанавливаем gitsync из hub.oscript.io..." {
        Push-Location $ProjectRoot
        try {
            opm install -l gitsync
            if ($LASTEXITCODE -ne 0) { throw "opm install gitsync завершился с кодом $LASTEXITCODE" }
        } finally {
            Pop-Location
        }
        Write-Host "gitsync установлен из реестра."
    }
} else {
    Invoke-Step "Устанавливаем gitsync из форка $GitsyncFork (ветка $GitsyncBranch)..." {
        $Tmp = Join-Path $env:TEMP ("gitsync-" + [System.IO.Path]::GetRandomFileName())
        try {
            git clone --depth 1 --branch $GitsyncBranch $GitsyncFork $Tmp
            if ($LASTEXITCODE -ne 0) { throw "git clone gitsync завершился с кодом $LASTEXITCODE" }

            Push-Location $Tmp
            try {
                opm build
                if ($LASTEXITCODE -ne 0) { throw "opm build завершился с кодом $LASTEXITCODE" }

                $ospx = Get-ChildItem $Tmp -Filter '*.ospx' | Select-Object -First 1
                if (-not $ospx) { throw "ospx-пакет не найден после opm build" }

                Push-Location $ProjectRoot
                try {
                    opm install -l -f $ospx.FullName
                    if ($LASTEXITCODE -ne 0) { throw "opm install завершился с кодом $LASTEXITCODE" }
                } finally {
                    Pop-Location
                }
            } finally {
                Pop-Location
            }
        } finally {
            if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
        }

        Write-Host "gitsync установлен в: $(Join-Path $ProjectRoot 'oscript_modules\bin\gitsync.bat')"
    }
}

# ---------------------------------------------------------------------------
# 2. Плагин МержВетки
# ---------------------------------------------------------------------------
Invoke-Step "Устанавливаем плагин МержВетки из $PluginRepo..." {
    $gitsync = Join-Path $ProjectRoot 'oscript_modules\bin\gitsync.bat'
    if (-not (Test-Path $gitsync)) {
        throw "gitsync.bat не найден в $ProjectRoot — убедитесь, что шаг 1 завершился успешно."
    }

    $env:GITSYNC_PLUGINS_PATH = Join-Path $ProjectRoot '.gitsync\plugins'

    $Tmp = Join-Path $env:TEMP ("gitsync-plugin-" + [System.IO.Path]::GetRandomFileName())
    try {
        git clone --depth 1 $PluginRepo $Tmp
        if ($LASTEXITCODE -ne 0) { throw "git clone plugin завершился с кодом $LASTEXITCODE" }

        Push-Location $Tmp
        try {
            opm build
            if ($LASTEXITCODE -ne 0) { throw "opm build завершился с кодом $LASTEXITCODE" }

            $ospx = Get-ChildItem $Tmp -Filter '*.ospx' | Select-Object -First 1
            if (-not $ospx) { throw "ospx-пакет не найден после opm build" }

            & $gitsync plugins install -f $ospx.FullName
            if ($LASTEXITCODE -ne 0) { throw "gitsync plugins install завершился с кодом $LASTEXITCODE" }
        } finally {
            Pop-Location
        }
    } finally {
        if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
    }

    & $gitsync plugins enable merge-branch
    if ($LASTEXITCODE -ne 0) { throw "gitsync plugins enable завершился с кодом $LASTEXITCODE" }

    Write-Host "Плагин установлен и включён:"
    & $gitsync plugins list
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Готово. Теперь можно запускать gitsync.ps1 в проекте."
