#!/bin/bash

main() {
    CONFIG_FILE="$1"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Файл конфигурации не найден"
        exit 1
    fi

    echo "Парсим конфиг..."

    parse_config "$CONFIG_FILE"

    echo "Проверяем возможность подключения к БД..."

    if ! check_db_connections; then
        log_error "Ошибка подключения к БД"
        exit 1
    fi
}

build_db_url() {
    local db_type="$1"
    local config_file="$2"

    local host=$(yq e ".$db_type.host" "$config_file")
    local port=$(yq e ".$db_type.port" "$config_file")
    local database=$(yq e ".$db_type.database" "$config_file")
    local username=$(yq e ".$db_type.username" "$config_file")
    local password=$(yq e ".$db_type.password" "$config_file")

    echo "postgresql://$username:$password@$host:$port/$database"
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

parse_config() {
    local config_file="$1"

    THREADS=$(yq e '.migration.threads' "$config_file")
    SOURCE_URL=$(build_db_url "source" "$config_file")
    TARGET_URL=$(build_db_url "target" "$config_file")

    SCHEMA_MODE=$(yq e '.migration.schemas.mode' "$config_file")
    SCHEMA_LIST=($(yq e '.migration.schemas.list[]' "$config_file"))

    ROLE_MODE=$(yq e '.migration.roles.mode' "$config_file")
    ROLE_LIST=($(yq e '.migration.roles.list[]' "$config_file" 2>/dev/null || true))

    TABLE_MODE=$(yq e '.migration.tables.mode' "$config_file")
    TABLE_LIST_JSON=$(yq e '.migration.tables.list' "$config_file" -o=json 2>/dev/null || echo "[]")

    INDEXES_AFTER_DATA=$(yq e '.migration.indexes_after_data // true' "$config_file")
    CONSTRAINTS_AFTER_DATA=$(yq e '.migration.constraints_after_data // true' "$config_file")

    log_info "Схемы: $SCHEMA_MODE (${#SCHEMA_LIST[@]})"
    log_info "Роли: $ROLE_MODE (${#ROLE_LIST[@]})"
    log_info "Таблицы: $TABLE_MODE ($(echo "$TABLE_LIST_JSON" | jq length))"
    log_info "Потоков: $THREADS"

    export THREADS SOURCE_URL TARGET_URL
    export SCHEMA_MODE SCHEMA_LIST ROLE_MODE ROLE_LIST TABLE_MODE TABLE_LIST_JSON
    export INDEXES_AFTER_DATA CONSTRAINTS_AFTER_DATA

}

check_db_connections() {
    log_info "Проверка подключения к исходной БД..."

    if ! psql "$SOURCE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "Не удалось подключиться к исходной БД: $SOURCE_URL"
        return 1
    fi

    log_info "Проверка подключения к целевой БД..."
    if ! psql "$TARGET_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "Не удалось подключиться к целевой БД: $TARGET_URL"
        return 1
    fi

    log_info "Подключения к БД проверены успешно"
    return 0
}

main "$1"
