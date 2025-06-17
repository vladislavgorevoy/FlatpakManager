#!/bin/bash

# Проверка наличия flatpak
if ! command -v flatpak &> /dev/null; then
    echo "Ошибка: flatpak не установлен. Установите его с помощью вашего пакетного менеджера."
    exit 1
fi

# Автоматическое определение директории скрипта (без readlink)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # разрешаем симлинки
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null && pwd)"

# Подкаталог для резервных копий
BACKUP_DIR="$SCRIPT_DIR/Backups"
DEFAULT_BACKUP_PREFIX="flatpak-backup-"

# Создаём каталог, если он не существует
mkdir -p "$BACKUP_DIR"

# Функция для вывода меню и выбора
menu_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local i=1

    echo "$prompt"
    for opt in "${options[@]}"; do
        echo "$i) $opt"
        ((i++))
    done

    read -p "Выберите номер: " choice
    echo "${options[$((choice-1))]}"
}

# Функция поиска резервных копий в подкаталоге Backups
find_backup_files() {
    find "$BACKUP_DIR" -maxdepth 1 -type f -name "${DEFAULT_BACKUP_PREFIX}*.txt" | sort -r
}

# Функция сохранения Flatpak в новую резервную копию
backup_flatpak_apps() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="$BACKUP_DIR/${DEFAULT_BACKUP_PREFIX}${timestamp}.txt"

    echo "Создаём резервную копию: $backup_file"

    echo "# ApplicationID | Remote | Installation" > "$backup_file"

    flatpak list --app --columns=application,origin,installation >> "$backup_file"

    if [ $? -eq 0 ]; then
        echo "Резервная копия успешно сохранена в:"
        echo "$backup_file"
    else
        echo "Ошибка при сохранении списка Flatpak."
        return 1
    fi
}

# Функция восстановления Flatpak из резервной копии
restore_flatpak_apps() {
    # Поиск всех резервных копий
    mapfile -t backup_files < <(find_backup_files)

    if [ ${#backup_files[@]} -eq 0 ]; then
        echo "❌ Не найдено резервных копий в каталоге:"
        echo "$BACKUP_DIR"
        return 1
    fi

    echo "Найдены следующие резервные копии:"
    local i=1
    for file in "${backup_files[@]}"; do
        echo "$i) $(basename "$file")"
        ((i++))
    done

    read -p "Выберите номер копии для восстановления: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#backup_files[@]} ]]; then
        echo "❌ Неверный выбор."
        return 1
    fi

    input_file="${backup_files[$((choice-1))]}"

    echo "Вы уверены, что хотите восстановить Flatpak-приложения? (y/n)"
    read -p "Подтвердите: " confirm
    [[ "$confirm" != "y" ]] && return 0

    while read -r app_id remote installation; do
        [[ -z "$app_id" || "$app_id" == \#* || "$app_id" == Application ]] && continue
        echo "Устанавливаем: $app_id из $remote ($installation)"
        flatpak install --$installation "$remote" "$app_id" -y
    done < "$input_file"

    echo "✅ Восстановление завершено."
}

# Основное меню
while true; do
    clear
    echo "=== Flatpak Менеджер ==="
    echo "1) Создать новую резервную копию"
    echo "2) Восстановить из резервной копии"
    echo "3) Выход"
    read -p "Выберите действие: " action

    case "$action" in
        1)
            backup_flatpak_apps
            ;;
        2)
            restore_flatpak_apps
            ;;
        3|*)
            echo "Выход."
            break
            ;;
    esac
    read -p "Нажмите Enter для продолжения..."
done
