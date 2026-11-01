# Сборка ReUnion через Docker (Windows + Linux)

Этот набор файлов позволяет собрать ReUnion для обеих платформ в изолированных Docker-контейнерах, не устанавливая компиляторы на хост-машину.

## Структура файлов

| Файл | Назначение |
|------|------------|
| `Dockerfile.linux` | Сборка под Linux (Debian 11, gcc-multilib, 32-bit .so) |
| `Dockerfile.windows` | Сборка под Windows (Server 2022, VS Build Tools 2022, .dll) |
| `docker-build.sh` | Bash-скрипт orchestration (Linux/Mac/WSL/Git Bash) |
| `build-docker.ps1` | PowerShell-скрипт orchestration (Windows) |
| `docker-compose.yml | Docker Compose конфигурация |
| `.dockerignore` | Исключения из контекста сборки Docker |

## Предварительные требования

- **Docker** (Docker Desktop для Windows/Mac, Docker Engine для Linux)
- Для Windows-контейнеров на Windows хосте: **WSL 2** или **Windows containers mode**

## Быстрый старт

### Linux/Mac/WSL (Bash)

```bash
chmod +x docker-build.sh

# Собрать под обе платформы
./docker-build.sh all

# Только Linux
./docker-build.sh linux

# Только Windows
./docker-build.sh windows

# Сборка без использования кэша Docker
./docker-build.sh all --no-cache

# Очистка Docker-образов и контейнеров
./docker-build.sh clean
```

### Windows (PowerShell)

```powershell
# Собрать под обе платформы
.\build-docker.ps1 -Target all

# Только Linux
.\build-docker.ps1 -Target linux

# Только Windows
.\build-docker.ps1 -Target windows

# Сборка без кэша
.\build-docker.ps1 -Target all -NoCache

# Очистка
.\build-docker.ps1 -Target clean
```

### Docker Compose

```bash
# Собрать оба образа
docker-compose build

# Запустить сборку (требует настройки томов для вывода)
docker-compose up
```

## Куда попадают готовые файлы

После успешной сборки артефакты находятся в:

```
build/output/
├── linux/
│   └── addons/
│       └── reunion/
│           └── reunion_mm_i386.so      # Linux плагин
└── windows/
    └── addons/
        └── reunion/
            └── reunion_mm.dll          # Windows плагин
```

## Установка на сервер

### Linux сервер
```bash
# Скопируйте плагин
cp build/output/linux/addons/reunion/reunion_mm_i386.so <gamedir>/addons/reunion/

# Скопируйте конфиг
cp reunion/dist/reunion.cfg <server_root>/

# Добавьте в plugins.ini (в начало файла)
echo "linux addons/reunion/reunion_mm_i386.so" >> <gamedir>/addons/metamod/plugins.ini
```

### Windows сервер
```cmd
:: Скопируйте плагин
copy build\output\windows\addons\reunion\reunion_mm.dll <gamedir>\addons\reunion\

:: Скопируйте конфиг
copy reunion\dist\reunion.cfg <server_root>\

:: Добавьте в plugins.ini (в начало файла)
echo win32 addons\reunion\reunion_mm.dll >> <gamedir>\addons\metamod\plugins.ini
```

## ⚠️ Важно: настройка конфига перед первым запуском

По умолчанию `reunion.cfg` имеет пустую `SteamIdHashSalt` с `AuthVersion = 4`, из-за чего плагин **не загрузится**. Обязательно отредактируйте `reunion.cfg`:

```
SteamIdHashSalt = aB3xK9mP2vR7wL4nQ8yJ1cH5fG6tD8sZ
AuthVersion = 4
```

Соль должна быть не менее 16 символов.

## Особенности Windows-образа

- Сборка Windows-образа может занять **20–40 минут** при первом запуске (скачивание и установка Visual Studio Build Tools ~5–7 ГБ).
- Требуется режим **Windows containers** в Docker Desktop, либо использование WSL 2 с бэкендом Hyper-V.
- Альтернативно: можно использовать готовый образ с предустановленными Build Tools.

## Особенности Linux-образа

- Используется Debian 11 (bullseye) из архивных репозиториев (так как ветка достигла EOL).
- Собирается 32-битный вариант (`-m32`), требуются `gcc-multilib` / `g++-multilib`.
- Бинарный файл: `reunion_mm_i386.so` (dynamically linked, без `-fPIC`).

## CI/CD интеграция

В репозитории уже есть `.github/workflows/build.yml`, который автоматически собирает плагин под Windows (Windows Server 2025 runner) и Linux (Debian 11 container) при каждом push. Docker-файлы в этом репозитории дублируют ту же логику для локальной сборки.

## Устранение неполадок

| Проблема | Решение |
|----------|---------|
| Docker не найден | Установите Docker Desktop или Docker Engine |
| Ошибка доступа к Docker demon | Добавьте пользователя в группу `docker` (Linux) или запустите от имени администратора (Windows) |
| Сборка Windows падает на этапе VS Build Tools | Убедитесь, что включены Windows containers в Docker Desktop |
| Плагин не загружается на сервере | Проверьте `SteamIdHashSalt` в `reunion.cfg` (см. раздел выше) |
| Архитектура не i386 | Убедитесь, что собрали с `-m32` (Linux) или `Platform=Win32` (Windows) |
