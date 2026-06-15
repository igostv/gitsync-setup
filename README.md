# gitsync-setup

Скрипт быстрой настройки [gitsync](https://github.com/oscript-library/gitsync) для проектов 1С.

Устанавливает:
- gitsync из форка с поддержкой приоритизации плагинов ([PR #364](https://github.com/oscript-library/gitsync/pull/364))
- плагин [МержВетки](https://github.com/igostv/gitsync-plugin-merge-branch)
- шаблоны `gitsync.ps1` и `env.ps1` в корень проекта

> После того как PR #364 влит в основной gitsync и опубликован в hub.oscript.io, используйте флаг `-UseRegistry`.

## Использование

### Быстрый старт (из корня проекта)

```powershell
irm https://raw.githubusercontent.com/igostv/gitsync-setup/master/setup-gitsync.ps1 | iex
```

### Клонировать и запустить

```powershell
git clone git@github.com:igostv/gitsync-setup.git
cd gitsync-setup
.\setup-gitsync.ps1 -ProjectRoot "D:\path\to\your\project"
```

### Параметры

| Параметр | По умолчанию | Описание |
|---|---|---|
| `-ProjectRoot` | текущий каталог | Корень проекта, куда устанавливается gitsync |
| `-UseRegistry` | выключен | Установить gitsync из hub.oscript.io (после влития PR #364) |

## После установки

Заполните в `env.ps1`:

```powershell
$env:GITSYNC_STORAGE_PATH = 'tcp://host/repo'
$env:GITSYNC_STORAGE_USER = 'Имя Пользователя'
$env:GITSYNC_STORAGE_PASSWORD = 'пароль'
$env:GITSYNC_V8VERSION = '8.3.27.1989'
```

Затем запускайте синхронизацию:

```powershell
.\gitsync.ps1
```

## Требования

- [OneScript](https://oscript.io) с `opm` в PATH
- `git` в PATH
- Доступ к github.com по SSH (`git@github.com:...`)
