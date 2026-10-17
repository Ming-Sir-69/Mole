<p align="right"><a href="https://github.com/tw93/Mole">macOS</a> · <b>Windows</b></p>

<div align="center">
  <h1>Mole CLI for Windows</h1>
  <p><b>Глубокая очистка, удаление приложений, оптимизация, анализ диска и мониторинг вашего ПК с Windows. Бесплатный CLI с открытым исходным кодом.</b></p>
  <p><a href="README.md">English</a> · <a href="README_CN.md">中文</a> · <a href="README_TW.md">繁體</a> · <a href="README_JA.md">日本語</a> · <a href="README_KR.md">한국어</a> · <a href="README_DE.md">Deutsch</a> · <a href="README_FR.md">Français</a> · <a href="README_UA.md">Українська</a> · Русский</p>
  <a href="https://github.com/tw93/mole/stargazers"><img src="https://img.shields.io/github/stars/tw93/mole?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/tw93/Mole/releases"><img src="https://img.shields.io/github/v/release/tw93/mole?filter=*-windows&include_prereleases&label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL_v3-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/tw93/mole/commits/windows"><img src="https://img.shields.io/github/commit-activity/m/tw93/mole/windows?style=flat-square" alt="Commits"></a>
  <a href="https://twitter.com/HiTw93"><img src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter" alt="Twitter"></a>
  <a href="https://t.me/+9f9gf4ZrFSQ2OWVl"><img src="https://img.shields.io/badge/chat-Telegram-blueviolet?style=flat-square&logo=Telegram" alt="Telegram"></a>
</div>

<p align="center">
  <img src="./docs/img/mole-windows.png" alt="Меню Mole CLI for Windows" width="1000" />
</p>

> 💡 Эта ветка содержит бесплатный CLI с открытым исходным кодом для Windows (`mo`). Нужно нативное приложение? [Mole for Windows](https://mole.fit/windows) загружается отдельно: очистка с просмотром перед удалением, обновление приложений, управление автозагрузкой, детальный разбор диска и состояние системы в реальном времени. CLI для macOS живёт в [ветке main](https://github.com/tw93/Mole).

## Возможности

- **Всё в одном CLI**: объединяет сценарии в духе CCleaner, IObit Uninstaller, WinDirStat и Диспетчера задач в одной команде терминала
- **Глубокая очистка**: удаляет временные файлы, кеши, журналы и остатки браузеров, освобождая место на диске
- **Умное удаление приложений**: удаляет приложения вместе с оставшимися папками установки
- **Анализ диска**: наглядно показывает, чем занят диск, в интерактивном TUI и находит крупные файлы
- **Обслуживание системы**: сбрасывает кеш DNS, оптимизирует системный диск и проверяет его состояние
- **Мониторинг в реальном времени**: показывает загрузку CPU, память, диск, сеть и статистику процессов

## Быстрый старт

Mole работает в Windows 10 и 11 со встроенным Windows PowerShell 5.1. Для установки скриптом нужен Git, а если источник отличается от последнего выпуска, то и Go для сборки нативных инструментов. Mole устанавливается в `%LOCALAPPDATA%\Programs\mole-cli` и добавляет `mo` и `mole` в PATH.

**Установка через Scoop**

```powershell
scoop install mole
```

**Или через скрипт**

```powershell
iwr -useb https://raw.githubusercontent.com/tw93/Mole/windows/quick-install.ps1 | iex
```

Mole распространяется только через этот репозиторий на GitHub, Scoop и [mole.fit](https://mole.fit/windows) (приложение для Windows). Сайты, которые предлагают приложение «на основе Mole» или просят вставить в терминал закодированную команду, не имеют к Mole никакого отношения.

**Запуск**

```powershell
mo                           # Интерактивное меню
mo clean                     # Глубокая очистка
mo uninstall                 # Удалить установленные приложения вместе с их остатками
mo optimize                  # Обновить кеши и службы
mo analyze                   # Наглядный обозреватель диска
mo status                    # Панель состояния системы в реальном времени
mo purge                     # Удалить артефакты сборки проектов

mo update                    # Обновить Mole
mo remove                    # Удалить Mole с этого ПК
mo --help                    # Показать справку
mo --version                 # Показать установленную версию
```

**Безопасный предпросмотр**

```powershell
mo clean --dry-run
mo uninstall --dry-run
mo optimize --dry-run
mo purge --dry-run
mo history
mo history --json

mo clean --dry-run --debug   # Предпросмотр + подробные журналы
mo clean --whitelist         # Управление защищёнными путями
mo clean --system            # Включить очистку системного уровня (запускайте от имени администратора)
mo purge --paths             # Настроить каталоги для поиска проектов
mo analyze D:\               # Анализировать другой диск
```

<details>
<summary><strong>Другие способы установки</strong></summary>

Чтобы просмотреть код перед установкой, клонируйте ветку `windows` и запустите установщик на месте. Каталог `.git` сохраняется, поэтому `mo update` будет работать и позже:

```powershell
$installDir = "$env:LOCALAPPDATA\Programs\mole-cli"
git clone --branch windows https://github.com/tw93/Mole.git $installDir
powershell -ExecutionPolicy Bypass -File "$installDir\install.ps1" -InstallDir $installDir -AddToPath
```

Добавьте `-CreateShortcut`, чтобы получить ярлык в меню «Пуск». Чтобы удалить Mole, выполните `mo remove`.

</details>

## Безопасность

Mole умеет удалять файлы, поэтому он проверяет пути и защищает системные расположения и профиль пользователя. `uninstall`, `purge` и `remove` запрашивают подтверждение перед любым удалением. Если Mole не может убедиться, что объект безопасно изменять, он пропускает его.

- `clean`, `uninstall` и `purge` могут удалять файлы, поэтому сначала просматривайте их с `--dry-run`, а при необходимости добавляйте `--debug`
- `clean` и `purge` удаляют безвозвратно; проверенные остатки `uninstall` попадают в Корзину, собственный деинсталлятор приложения сохраняет своё поведение, а файлы, удалённые в `mo analyze`, также попадают в Корзину
- Запускайте Mole от обычного пользователя; шаги системного уровня пропускаются, если PowerShell запущен не от имени администратора
- Защищайте пути через `mo clean --whitelist`
- Действия по очистке записываются в `%USERPROFILE%\.config\mole\operations.log`; просмотреть их можно командой `mo history`, а отключить запись можно переменной `MO_NO_OPLOG=1`
- `C:\Windows`, `C:\Program Files`, папки Windows Defender и корень вашего профиля никогда не затрагиваются

Загляните в [SECURITY.md](SECURITY.md), чтобы узнать, как сообщать о проблемах и какие границы безопасности действуют.

## Подробнее о возможностях

Примеры ниже сокращены. Доступные пункты и размеры зависят от вашего ПК.

### Очистка (Clean)

```powershell
mo clean --dry-run
```

```
Clean Your Windows

Dry Run Mode - Preview only, no deletions

⚙ Microsoft Windows 11 Pro | Free space: 100.34GB

➤ User essentials
  → User temp files (>7d old) (109 items, 529.3MB dry)
  → Thumbnail cache (15 items, 11.1MB dry)
  → Memory dumps (10 items, 72.0MB dry)

➤ Browser caches
  → Edge Cache (2 items, 95.0MB dry)
  → Edge Code Cache (2 items, 26.5MB dry)

➤ Developer tools
  → NuGet HTTP cache (1 items, 596.1MB dry)

Dry run complete - no changes made

  Potential space: 1.32GB | Items: 176

  Detailed list: C:\Users\you\.config\mole\clean-list.txt
  Run without --dry-run to apply cleanup
```

Подробный список содержит все пути, найденные при предпросмотре. Скопируйте любой из них в белый список, чтобы сохранить его.

### Удаление приложений (Uninstall)

```powershell
mo uninstall
```

Показывает установленные программы из реестра и Windows Apps, начиная с самых крупных, затем удаляет выбранные вами через их собственный деинсталлятор и очищает оставшуюся папку установки. `mo uninstall --dry-run` показывает, какой деинсталлятор будет использован для каждого приложения и что будет удалено, ничего не запуская.

```text
$ mo uninstall

Select Applications to Uninstall

Use: ↑↓ navigate | Space select | Enter confirm | Q quit | / search

  [✓] VLC media player                              176.4MB
  [✓] Notepad++ (64-bit x64)                         15.2MB
  [ ] 7-Zip 24.08 (x64)                               5.6MB

Selected: 2 apps (191.6MB)
Page 1 of 1

The following applications will be uninstalled:

  • VLC media player (176.4MB)
  • Notepad++ (64-bit x64) (15.2MB)

Continue? (y/N): y

Uninstalling Applications

➤ Uninstalling: VLC media player ✓
  Cleaning leftover files...
➤ Uninstalling: Notepad++ (64-bit x64) ✓

Uninstall Complete
  Successfully uninstalled: 2
```

### Оптимизация (Optimize)

```powershell
mo optimize --dry-run
```

```
Optimize and Maintain

 DRY RUN MODE - No changes will be made

⚙ System  6.2/12GB RAM | 154/254GB Disk | Uptime 4.1d

➤ DNS Cache
  → Would flush DNS cache

➤ Disk Health
  ✓ harddisk SSD - Healthy

Dry Run Complete - No Changes Made

  Would apply 1 optimization
  Run without --dry-run to apply changes
```

Шаги вроде оптимизации диска и сброса кеша ARP требуют прав администратора и без них пропускаются; запустите PowerShell от имени администратора, чтобы включить их.

### Анализ диска (Analyze)

```powershell
mo analyze
mo analyze D:\
```

<img src="./docs/img/analyze-windows.png" alt="Обзор mo analyze" width="1000" />

Интерактивный обозреватель диска с тем же интерфейсом, что и в версии для macOS: стрелки перемещают по папкам, `Backspace` возвращает назад, `T` показывает самые крупные файлы, а `Del` после подтверждения перемещает выбранные объекты в Корзину.

### Состояние системы (Status)

```powershell
mo status
```

<img src="./docs/img/status-windows.png" alt="Панель mo status" width="1000" />

Панель в реальном времени с оценкой состояния, CPU, памятью, диском, питанием, сетью и самыми активными процессами.

### Очистка проектов (Purge)

```powershell
mo purge --dry-run
```

Находит артефакты сборки (`node_modules`, `target`, `build`, `dist`, `venv` и другие) в папках ваших проектов и позволяет выбрать, какие проекты очистить; пока вы не сделаете выбор, ничего не отмечено. Настроить сканируемые папки можно командой `mo purge --paths`.

## Сообщество

Спасибо всем, кто помогал создавать Mole. Подпишитесь на них! ❤️

<a href="https://github.com/tw93/Mole/graphs/contributors">
  <img src="./CONTRIBUTORS.svg?v=2" alt="Контрибьюторы Mole" width="1000" />
</a>

## Поддержать проект

- Самый прямой способ поддержать разработку Mole: приобрести [Mole for Windows](https://mole.fit/windows)
- Если Mole вам помог, поставьте звезду, [расскажите о нём](https://twitter.com/intent/tweet?url=https://github.com/tw93/Mole/tree/windows&text=Mole%20-%20Deep%20clean%20and%20optimize%20your%20Windows%20PC.) или откройте issue либо PR
- Вклад в проект приветствуется; сначала прочитайте [CONTRIBUTING.md](CONTRIBUTING.md)
- У меня двое котов, TangYuan и Coke; если Mole хоть немного облегчил вам жизнь, можете угостить их <a href="https://cats.tw93.fun?name=Mole" target="_blank">консервами 🥩</a>

## Лицензия

Mole представляет собой программное обеспечение с открытым исходным кодом под лицензией GPL-3.0; подробности в [LICENSE](LICENSE). Любая изменённая версия, которую вы распространяете, должна оставаться под той же лицензией. Если вы делаете форк Mole, пожалуйста, дайте ему другое название и укажите Mole как первоисточник; см. [TRADEMARK.md](TRADEMARK.md).
