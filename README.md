# gitsync-setup

Скрипт быстрой настройки [gitsync](https://github.com/oscript-library/gitsync) для проектов 1С.

Устанавливает:
- gitsync из форка с поддержкой приоритизации плагинов ([PR #364](https://github.com/oscript-library/gitsync/pull/364))
- плагин [МержВетки](https://github.com/igostv/gitsync-plugin-merge-branch)
- шаблон `gitsync.ps1` и пример настроек `.vrunner.json.example` в корень проекта

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

Скопируйте `.vrunner.json.example` в `.vrunner.json` и заполните настройки подключения:

```json
{
  "v8version": "8.3.27.1989",
  "connection": "tcp://host/repo",
  "db-user": "Имя Пользователя",
  "db-pwd": "пароль",
  "gitsync-workdir": "src/cf"
}
```

Файл `.vrunner.json` автоматически добавляется в `.gitignore` — пароли не попадут в репозиторий.

Формат совместим с [vanessa-runner](https://github.com/Pr-Mex/vanessa-runner) и расширениями VS Code для 1С (Yellow Hummer 1C Tools и аналоги).

Затем запускайте синхронизацию:

```powershell
.\gitsync.ps1
```

## Требования

- [OneScript](https://oscript.io) с `opm` в PATH
- `git` в PATH
- Доступ к github.com по SSH (`git@github.com:...`)
