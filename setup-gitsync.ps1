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

$utf8 = [System.Text.Encoding]::UTF8
$OutputEncoding = $utf8
[Console]::InputEncoding  = $utf8
[Console]::OutputEncoding = $utf8
chcp 65001 > $null

$ErrorActionPreference = 'Stop'

$GitsyncFork    = 'git@github.com:igostv/gitsync.git'
$GitsyncBranch  = 'feature/plugin-priority-sorting'
$PluginRepo     = 'git@github.com:igostv/gitsync-plugin-merge-branch.git'

# Таблица соответствия версий gitsync → gitsync-plugins
# Источник: readme.md в пакете gitsync (раздел "Настройка плагинов синхронизации")
$PluginsVersionMap = @{
    '3.7.3' = '2.0.3'
    '3.7.2' = '2.0.3'
    '3.7.1' = '2.0.1'
    '3.7.0' = '2.0.0'
}

function Get-GitsyncVersion {
    $metaPath = Join-Path $ProjectRoot 'oscript_modules\gitsync\opm-metadata.xml'
    if (-not (Test-Path $metaPath)) { return $null }
    [xml]$meta = Get-Content $metaPath -Encoding UTF8
    return $meta.'opm-metadata'.version
}

function Get-PluginsVersion([string]$GitsyncVer) {
    if ($PluginsVersionMap.ContainsKey($GitsyncVer)) {
        return $PluginsVersionMap[$GitsyncVer]
    }
    Write-Warning "Версия gitsync $GitsyncVer отсутствует в таблице соответствия — установим последнюю gitsync-plugins"
    return $null
}

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
# 1.5. Патч ПодключениеПлагиновКаталога.os
# ---------------------------------------------------------------------------
# Плагины используют #Использовать 1commands внутри файлов .os, и при загрузке
# через ПодключитьСценарий OneScript пытается перезарегистрировать уже
# загруженный класс Команда — это вызывает KeyNotFoundException.
# Обёртка Попытка/Исключение позволяет пропустить конфликт и продолжить.
Invoke-Step "Патчим ПодключениеПлагиновКаталога.os..." {
    $patchTarget = Join-Path $ProjectRoot `
        'oscript_modules\gitsync\src\core\Классы\internal\Классы\ПодключениеПлагиновКаталога.os'
    if (-not (Test-Path $patchTarget)) {
        throw "Файл для патча не найден: $patchTarget"
    }

    $lines = [System.IO.File]::ReadAllLines($patchTarget, [System.Text.Encoding]::UTF8)

    if ($lines | Where-Object { $_.TrimStart() -eq 'Попытка' }) {
        Write-Host "Патч уже применён ранее, пропускаем."
    } else {
        $target = 'ПодключитьСценарий(ФайлКласса.ПолноеИмя, Идентификатор);'
        $idx = -1
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i].TrimStart() -eq $target) { $idx = $i; break }
        }
        if ($idx -lt 0) { throw "Не удалось найти строку для патча в $patchTarget" }

        $tab  = [string][char]9
        $lead = $lines[$idx].Substring(0, $lines[$idx].Length - $lines[$idx].TrimStart().Length)
        $result = [System.Collections.Generic.List[string]]::new()
        foreach ($ln in $lines[0..($idx - 1)]) { $result.Add($ln) }
        $result.Add("$lead" + "Попытка")
        $result.Add("$lead$tab" + $target)
        $result.Add("$lead$tab" + "МассивПодключенныхПлагинов.Добавить(Идентификатор);")
        $result.Add("$lead" + "Исключение")
        $result.Add("$lead$tab" + "Лог.Отладка(`"Пропускаем класс <%1> (конфликт имён): <%2>`", Идентификатор, ОписаниеОшибки());")
        $result.Add("$lead" + "КонецПопытки;")
        foreach ($ln in $lines[($idx + 2)..($lines.Length - 1)]) { $result.Add($ln) }

        [System.IO.File]::WriteAllLines($patchTarget, $result, [System.Text.Encoding]::UTF8)
        Write-Host "Патч применён."
    }
}

# ---------------------------------------------------------------------------
# 2. Плагины в oscript_modules
# ---------------------------------------------------------------------------
Invoke-Step "Устанавливаем плагины в oscript_modules..." {
    $gitsync = Join-Path $ProjectRoot 'oscript_modules\bin\gitsync.bat'
    if (-not (Test-Path $gitsync)) {
        throw "gitsync.bat не найден в $ProjectRoot — убедитесь, что шаг 1 завершился успешно."
    }

    $env:GITSYNC_PLUGINS_PATH = Join-Path $ProjectRoot 'oscript_modules'

    # Стандартные плагины: версия соответствует gitsync
    $GitsyncVer = Get-GitsyncVersion
    $PluginsVer = if ($GitsyncVer) { Get-PluginsVersion $GitsyncVer } else { $null }
    $PluginsPkg = if ($PluginsVer) { "gitsync-plugins@$PluginsVer" } else { 'gitsync-plugins' }
    Write-Host "gitsync $GitsyncVer -> $PluginsPkg"

    Push-Location $ProjectRoot
    try {
        opm install -l $PluginsPkg
        if ($LASTEXITCODE -ne 0) { throw "opm install $PluginsPkg завершился с кодом $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

    # Плагин МержВетки — собираем из репозитория и устанавливаем через opm install -l
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

            Push-Location $ProjectRoot
            try {
                opm install -l -f $ospx.FullName
                if ($LASTEXITCODE -ne 0) { throw "opm install plugin завершился с кодом $LASTEXITCODE" }
            } finally {
                Pop-Location
            }
        } finally {
            Pop-Location
        }
    } finally {
        if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
    }

    # Включаем плагины
    Push-Location $ProjectRoot
    try {
        foreach ($plugin in @('merge-branch', 'check-authors', 'check-comments', 'sync-remote', 'use-ibcmd')) {
            & $gitsync plugins enable $plugin
            if ($LASTEXITCODE -ne 0) { throw "gitsync plugins enable $plugin завершился с кодом $LASTEXITCODE" }
        }

        Write-Host "Плагины установлены и включены:"
        & $gitsync plugins list
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# 4. Шаблоны gitsync.ps1 и env.ps1
# ---------------------------------------------------------------------------
Invoke-Step "Копируем файлы запуска в проект..." {
    $RepoBase = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
    $RawBase  = 'https://raw.githubusercontent.com/igostv/gitsync-setup/master'

    function Copy-Template([string]$Name) {
        $Dest = Join-Path $ProjectRoot $Name
        if (Test-Path $Dest) {
            Write-Host "Пропущен (уже существует): $Dest"
            return
        }

        if ($RepoBase) {
            Copy-Item (Join-Path $RepoBase $Name) $Dest
        } else {
            (irm "$RawBase/$Name") | Set-Content $Dest -Encoding UTF8
        }
        Write-Host "Создан: $Dest"
    }

    Copy-Template 'gitsync.ps1'
    Copy-Template 'env.ps1'

    Write-Host ""
    Write-Host "  -> Заполните в env.ps1: GITSYNC_STORAGE_PATH, GITSYNC_STORAGE_USER, GITSYNC_STORAGE_PASSWORD, GITSYNC_V8VERSION"
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Готово. Заполните env.ps1 и запускайте .\gitsync.ps1"
