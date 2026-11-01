#!/bin/bash
# =============================================================================
# Скрипт сборки ReUnion для Windows и Linux через Docker
# Требуется: Docker (или Docker Desktop) установлен и запущен
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_LINUX="reunion-build-linux"
IMAGE_WINDOWS="reunion-build-windows"
CONTAINER_LINUX="reunion-build-linux-container"
CONTAINER_WINDOWS="reunion-build-windows-container"

usage() {
    echo "Использование: $0 [linux|windows|all|clean] [опции]"
    echo ""
    echo "Команды:"
    echo "  linux       Собрать только под Linux (reunion_mm_i386.so)"
    echo "  windows     Собрать только под Windows (reunion_mm.dll)"
    echo "  all         Собрать под обе платформы (по умолчанию)"
    echo "  clean       Удалить все Docker-образы и контейнеры сборки"
    echo ""
    echo "Опции:"
    echo "  --no-cache  Отключить кэш Docker при сборке"
    echo "  -h, --help  Показать эту справку"
    exit 0
}

NO_CACHE=0
TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        linux)   TARGET="linux"; shift ;;
        windows) TARGET="windows"; shift ;;
        all)     TARGET="all"; shift ;;
        clean)   TARGET="clean"; shift ;;
        --no-cache) NO_CACHE=1; shift ;;
        -h|--help) usage ;;
        *) echo "Неизвестный аргумент: $1"; usage ;;
    esac
done

DOCKER_BUILD_ARGS=""
if [[ "$NO_CACHE" -eq 1 ]]; then
    DOCKER_BUILD_ARGS="--no-cache"
fi

ensure_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "ОШИБКА: Docker не запущен или не установлен."
        echo "Установите Docker Desktop (Windows/Mac) или Docker Engine (Linux) и попробуйте снова."
        exit 1
    fi
}

cleanup() {
    echo "=== Очистка Docker-ресурсов ==="
    docker rm -f "$CONTAINER_LINUX" 2>/dev/null || true
    docker rm -f "$CONTAINER_WINDOWS" 2>/dev/null || true
    docker rmi -f "$IMAGE_LINUX" 2>/dev/null || true
    docker rmi -f "$IMAGE_WINDOWS" 2>/dev/null || true
    echo "Готово."
}

build_linux() {
    echo "=========================================="
    echo "  Сборка ReUnion под Linux (Docker)"
    echo "=========================================="
    ensure_docker

    echo "Сборка Docker-образа: $IMAGE_LINUX"
    docker build $DOCKER_BUILD_ARGS \
        -f "$REPO_ROOT/Dockerfile.linux" \
        -t "$IMAGE_LINUX" \
        "$REPO_ROOT"

    echo "Запуск контейнера и извлечение артефактов..."
    docker rm -f "$CONTAINER_LINUX" 2>/dev/null || true
    docker create --name "$CONTAINER_LINUX" "$IMAGE_LINUX" >/dev/null

    mkdir -p "$REPO_ROOT/build/output/linux"
    docker cp "$CONTAINER_LINUX:/publish/." "$REPO_ROOT/build/output/linux/"
    docker rm -f "$CONTAINER_LINUX" >/dev/null

    echo ""
    echo "=== Linux сборка завершена ==="
    echo "Артефакты: $REPO_ROOT/build/output/linux/"
    ls -la "$REPO_ROOT/build/output/linux/addons/reunion/" 2>/dev/null || true
}

build_windows() {
    echo "=========================================="
    echo "  Сборка ReUnion под Windows (Docker)"
    echo "=========================================="
    ensure_docker

    echo "Сборка Docker-образа: $IMAGE_WINDOWS (может занять 20-40 мин)"
    docker build $DOCKER_BUILD_ARGS \
        -f "$REPO_ROOT/Dockerfile.windows" \
        -t "$IMAGE_WINDOWS" \
        "$REPO_ROOT"

    echo "Запуск контейнера и извлечение артефактов..."
    docker rm -f "$CONTAINER_WINDOWS" 2>/dev/null || true
    docker create --name "$CONTAINER_WINDOWS" "$IMAGE_WINDOWS" >/dev/null

    mkdir -p "$REPO_ROOT/build/output/windows"
    docker cp "$CONTAINER_WINDOWS:C:\publish\." "$REPO_ROOT/build/output/windows/"
    docker rm -f "$CONTAINER_WINDOWS" >/dev/null

    echo ""
    echo "=== Windows сборка завершена ==="
    echo "Артефакты: $REPO_ROOT/build/output/windows/"
    ls -la "$REPO_ROOT/build/output/windows/addons/reunion/" 2>/dev/null || true
}

case "$TARGET" in
    clean)
        cleanup
        ;;
    linux)
        build_linux
        ;;
    windows)
        build_windows
        ;;
    all)
        build_linux
        build_windows
        ;;
esac
