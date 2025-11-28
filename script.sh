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

    # Таблицы - только из секции tables, игнорируем другие секции
    MIGRATION_CONFIG_JSON="["
    first_table=true

    # Ищем секцию tables и берем только имена таблиц из нее
    in_tables_section=false
    while IFS= read -r line; do
        # Начало секции tables
        if [[ "$line" =~ ^[[:space:]]*tables: ]]; then
            in_tables_section=true
            continue
        fi

        # Конец секции tables (новая секция на том же уровне)
        if [[ "$in_tables_section" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-z_]+: ]] && ! [[ "$line" =~ ^[[:space:]]+- ]]; then
            break
        fi

        # Ищем имя таблицы внутри секции tables
        if [[ "$in_tables_section" == true ]] && [[ "$line" =~ name:[[:space:]]*\"([^\"]+)\" ]]; then
            table_name="${BASH_REMATCH[1]}"
            if [ "$first_table" = true ]; then
                first_table=false
            else
                MIGRATION_CONFIG_JSON+=","
            fi
            MIGRATION_CONFIG_JSON+="{\"table\":\"$table_name\"}"
        fi
    done < "$CONFIG_FILE"

    MIGRATION_CONFIG_JSON+="]"

    # Роли
    ROLES_MODE=$(grep -A5 "roles:" "$CONFIG_FILE" | grep "mode:" | cut -d: -f2 | tr -d ' "')

    # Ищем имя роли (только в секции roles)
    ROLE_NAME=""
    ROLE_TABLE=""
    ROLE_PERMISSIONS=""

    in_roles_section=false
    in_list_section=false
    in_privileges_section=false

    while IFS= read -r line; do
        # Начало секции roles
        if [[ "$line" =~ ^[[:space:]]*roles: ]]; then
            in_roles_section=true
            continue
        fi

        # Выход из секции roles
        if [[ "$in_roles_section" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-z_]+: ]] && ! [[ "$line" =~ ^[[:space:]]+- ]] && ! [[ "$line" =~ ^[[:space:]]+[a-z_]+: ]]; then
            break
        fi

        # В секции roles
        if [[ "$in_roles_section" == true ]]; then
            # Секция list
            if [[ "$line" =~ ^[[:space:]]+list: ]]; then
                in_list_section=true
                continue
            fi

            # Имя роли в list
            if [[ "$in_list_section" == true ]] && [[ "$line" =~ name:[[:space:]]*\"([^\"]+)\" ]]; then
                ROLE_NAME="${BASH_REMATCH[1]}"
                continue
            fi

            # Секция table_privileges
            if [[ "$line" =~ ^[[:space:]]+table_privileges: ]]; then
                in_privileges_section=true
                continue
            fi

            # Таблица в privileges
            if [[ "$in_privileges_section" == true ]] && [[ "$line" =~ table:[[:space:]]*\"([^\"]+)\" ]]; then
                ROLE_TABLE="${BASH_REMATCH[1]}"
                continue
            fi

            # Permissions в privileges
            if [[ "$in_privileges_section" == true ]] && [[ "$line" =~ permissions:[[:space:]]*\[(.*)\] ]]; then
                ROLE_PERMISSIONS="${BASH_REMATCH[1]}"
                # Убираем кавычки и пробелы
                ROLE_PERMISSIONS=$(echo "$ROLE_PERMISSIONS" | sed 's/\"//g; s/ //g')
                break
            fi
        fi
    done < "$CONFIG_FILE"

    # Формируем JSON для ролей
    ROLES_LIST="[]"
    if [[ -n "$ROLE_NAME" && -n "$ROLE_TABLE" && -n "$ROLE_PERMISSIONS" ]]; then
        # Преобразуем permissions в массив JSON
        IFS=',' read -ra PERM_ARRAY <<< "$ROLE_PERMISSIONS"
        PERMISSIONS_JSON=""
        first_perm=true
        for perm in "${PERM_ARRAY[@]}"; do
            if [ "$first_perm" = true ]; then
                first_perm=false
            else
                PERMISSIONS_JSON+=","
            fi
            PERMISSIONS_JSON+="\"$perm\""
        done

        ROLES_LIST="[{\"name\":\"$ROLE_NAME\",\"table_privileges\":[{\"table\":\"$ROLE_TABLE\",\"permissions\":[$PERMISSIONS_JSON]}]}]"
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