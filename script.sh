#!/bin/bash

main() {
    CONFIG_FILE="$1"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[ERROR] Файл конфигурации не найден"
        exit 1
    fi

    echo "Парсим конфиг..."

    SOURCE_HOST=$(grep -A5 "source:" "$CONFIG_FILE" | grep "host:" | cut -d: -f2 | tr -d ' "')
    SOURCE_PORT=$(grep -A5 "source:" "$CONFIG_FILE" | grep "port:" | cut -d: -f2 | tr -d ' "')
    SOURCE_DATABASE=$(grep -A5 "source:" "$CONFIG_FILE" | grep "database:" | cut -d: -f2 | tr -d ' "')
    SOURCE_USERNAME=$(grep -A5 "source:" "$CONFIG_FILE" | grep "username:" | cut -d: -f2 | tr -d ' "')
    SOURCE_PASSWORD=$(grep -A5 "source:" "$CONFIG_FILE" | grep "password:" | cut -d: -f2 | tr -d ' "')

    TARGET_HOST=$(grep -A5 "target:" "$CONFIG_FILE" | grep "host:" | cut -d: -f2 | tr -d ' "')
    TARGET_PORT=$(grep -A5 "target:" "$CONFIG_FILE" | grep "port:" | cut -d: -f2 | tr -d ' "')
    TARGET_DATABASE=$(grep -A5 "target:" "$CONFIG_FILE" | grep "database:" | cut -d: -f2 | tr -d ' "')
    TARGET_USERNAME=$(grep -A5 "target:" "$CONFIG_FILE" | grep "username:" | cut -d: -f2 | tr -d ' "')
    TARGET_PASSWORD=$(grep -A5 "target:" "$CONFIG_FILE" | grep "password:" | cut -d: -f2 | tr -d ' "')

    THREADS=$(grep "threads:" "$CONFIG_FILE" | head -1 | cut -d: -f2 | tr -d ' "')

    echo "[DEBUG] Начинаем парсинг таблиц..."

    # Таблицы - grep + ручная сборка JSON
    TABLES=$(grep -A 10 "tables:" "$CONFIG_FILE" | grep -E "name:|where:|limit:" | sed 's/^[ ]*//')
    MIGRATION_CONFIG_JSON="["
    current_table=""
    while IFS= read -r line; do
        if [[ "$line" =~ name:\ \"(.*)\" ]]; then
            if [[ -n "$current_table" ]]; then
                MIGRATION_CONFIG_JSON+="},"
            fi
            current_table="${BASH_REMATCH[1]}"
            MIGRATION_CONFIG_JSON+="{\"table\":\"$current_table\""
        elif [[ "$line" =~ where:\ \"(.*)\" ]]; then
            MIGRATION_CONFIG_JSON+=",\"where\":\"${BASH_REMATCH[1]}\""
        elif [[ "$line" =~ limit:\ ([0-9]+) ]]; then
            MIGRATION_CONFIG_JSON+=",\"limit\":${BASH_REMATCH[1]}"
        fi
    done <<< "$TABLES"
    if [[ -n "$current_table" ]]; then
        MIGRATION_CONFIG_JSON+="}"
    fi
    MIGRATION_CONFIG_JSON+="]"

    # Роли - grep + ручная сборка JSON
    ROLES_MODE=$(grep -A5 "roles:" "$CONFIG_FILE" | grep "mode:" | cut -d: -f2 | tr -d ' "')

    ROLES_LIST="["
    ROLES_SECTION=$(grep -A 20 "roles:" "$CONFIG_FILE")

    current_role=""
    current_table=""
    current_permissions=""
    in_role=0
    in_privileges=0

    while IFS= read -r line; do
        # Начало роли
        if [[ "$line" =~ -\ name:\ \"(.*)\" ]]; then
            if [[ -n "$current_role" ]]; then
                ROLES_LIST+="{\"name\":\"$current_role\",\"table_privileges\":[$current_table]}"
            fi
            current_role="${BASH_REMATCH[1]}"
            current_table=""
            in_role=1
            in_privileges=0

        # Начало table_privileges
        elif [[ "$line" =~ table_privileges: ]] && [[ $in_role -eq 1 ]]; then
            in_privileges=1

        # Таблица в привилегиях
        elif [[ "$line" =~ -\ table:\ \"(.*)\" ]] && [[ $in_privileges -eq 1 ]]; then
            if [[ -n "$current_table" ]]; then
                current_table+=","
            fi
            current_table+="{\"table\":\"${BASH_REMATCH[1]}\",\"permissions\":["
            current_permissions=""

        # Permissions
        elif [[ "$line" =~ permissions:\ \[(.*)\] ]] && [[ $in_privileges -eq 1 ]]; then
            perms="${BASH_REMATCH[1]}"
            # Чистим permissions от кавычек и пробелов
            perms=$(echo "$perms" | sed 's/\"//g; s/ //g')
            IFS=',' read -ra perm_array <<< "$perms"
            for perm in "${perm_array[@]}"; do
                if [[ -n "$current_permissions" ]]; then
                    current_permissions+=","
                fi
                current_permissions+="\"$perm\""
            done
            current_table+="$current_permissions]}"
            current_permissions=""

        # Конец роли (новая роль или конец секции)
        elif [[ "$line" =~ ^[^[:space:]] ]] && [[ $in_role -eq 1 ]]; then
            if [[ -n "$current_role" ]]; then
                if [[ -n "$ROLES_LIST" ]] && [[ "$ROLES_LIST" != "[" ]]; then
                    ROLES_LIST+=","
                fi
                ROLES_LIST+="{\"name\":\"$current_role\",\"table_privileges\":[$current_table]}"
            fi
            break
        fi
    done <<< "$ROLES_SECTION"

    # Добавляем последнюю роль
    if [[ -n "$current_role" ]]; then
        if [[ "$ROLES_LIST" != "[" ]]; then
            ROLES_LIST+=","
        fi
        ROLES_LIST+="{\"name\":\"$current_role\",\"table_privileges\":[$current_table]}"
    fi

    ROLES_LIST+="]"

    # Если не нашли роли, используем пустой массив
    if [[ "$ROLES_LIST" == "[]" ]] || [[ -z "$ROLES_LIST" ]]; then
        ROLES_LIST="[]"
    fi
    # Если не нашли роли, используем пустой массив
    if [[ "$ROLES_LIST" == "[" ]] || [[ -z "$ROLES_LIST" ]] || [[ "$ROLES_LIST" == "[]" ]]; then
        ROLES_LIST="[]"
    fi

    # Если не нашли таблицы, используем пустой массив
    if [[ "$MIGRATION_CONFIG_JSON" == "[" ]] || [[ -z "$MIGRATION_CONFIG_JSON" ]] || [[ "$MIGRATION_CONFIG_JSON" == "[]" ]]; then
        MIGRATION_CONFIG_JSON="[]"
    fi

    echo "[INFO] === КОНФИГУРАЦИЯ ==="
    echo "[INFO] Исходная БД: $SOURCE_HOST:$SOURCE_PORT/$SOURCE_DATABASE"
    echo "[INFO] Целевая БД: $TARGET_HOST:$TARGET_PORT/$TARGET_DATABASE"
    echo "[INFO] Потоков: $THREADS"
    echo "[INFO] Конфиг таблиц: $MIGRATION_CONFIG_JSON"
    echo "[INFO] Режим ролей: $ROLES_MODE"
    echo "[INFO] Список ролей: $ROLES_LIST"
    echo "[INFO] ====================="

    echo "[INFO] Запускаем Go приложение..."

    echo "[INFO] Собираем Docker образ..."
    if docker build -t go-migrator .; then
        echo "[INFO] Запускаем контейнер..."

        docker run --rm \
            -e "SOURCE_DB_HOST=$SOURCE_HOST" \
            -e "SOURCE_DB_PORT=$SOURCE_PORT" \
            -e "SOURCE_DB_NAME=$SOURCE_DATABASE" \
            -e "SOURCE_DB_USERNAME=$SOURCE_USERNAME" \
            -e "SOURCE_DB_PASSWORD=$SOURCE_PASSWORD" \
            -e "TARGET_DB_HOST=$TARGET_HOST" \
            -e "TARGET_DB_PORT=$TARGET_PORT" \
            -e "TARGET_DB_NAME=$TARGET_DATABASE" \
            -e "TARGET_DB_USERNAME=$TARGET_USERNAME" \
            -e "TARGET_DB_PASSWORD=$TARGET_PASSWORD" \
            -e "MIGRATION_THREADS=$THREADS" \
            -e "MIGRATION_CONFIG_JSON=$MIGRATION_CONFIG_JSON" \
            -e "ROLES_MODE=$ROLES_MODE" \
            -e "ROLES_LIST=$ROLES_LIST" \
            go-migrator

        if [ $? -eq 0 ]; then
            echo "[INFO] Go приложение завершилось успешно"
        else
            echo "[ERROR] Go приложение завершилось с ошибкой"
            exit 1
        fi
    else
        echo "[ERROR] Ошибка сборки Docker образа"
        exit 1
    fi
}

main "$1"