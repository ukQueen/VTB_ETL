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

    DUMP_PATH=$(grep -A3 "dumb:" "$CONFIG_FILE" | grep "path:" | cut -d: -f2- | sed 's/^[ \t]*"//;s/"[ \t]*$//')

    THREADS=$(grep "threads:" "$CONFIG_FILE" | head -1 | cut -d: -f2 | tr -d ' "')

    MIGRATION_CONFIG_JSON="["
    FIRST_TABLE=true

    echo "[DEBUG] Начинаем парсинг таблиц..."

    MIGRATION_CONFIG_JSON=$(awk '
    BEGIN {
        first = 1
        print "["
    }
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ {
        if (!first) {
            printf ",\n"
        }
        first = 0

        # Извлекаем имя таблицы
        gsub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"|\"[[:space:]]*$/, "")
        table_name = $0
        where_condition = ""
        limit_value = ""
        orderby_value = ""

        # Читаем следующие строки для условий
        while (getline > 0) {
            # Если нашли следующую таблицу, выходим
            if (/^[[:space:]]*-[[:space:]]*name:/) {
                # Откатываем одну строку назад для следующей итерации
                system("exit") # Это не сработает, нужно по-другому
                break
            }

            # Парсим where
            if (/^[[:space:]]*where:[[:space:]]*/) {
                gsub(/^[[:space:]]*where:[[:space:]]*\"|\"[[:space:]]*$/, "")
                where_condition = $0
            }

            # Парсим limit
            if (/^[[:space:]]*limit:[[:space:]]*/) {
                gsub(/^[[:space:]]*limit:[[:space:]]*/, "")
                limit_value = $0
            }

            # Парсим orderby
            if (/^[[:space:]]*orderby:[[:space:]]*/) {
                gsub(/^[[:space:]]*orderby:[[:space:]]*\"|\"[[:space:]]*$/, "")
                orderby_value = $0
            }

            # Если пустая строка или конец секции, выходим
            if (/^[[:space:]]*$/ || /^[^[:space:]]/) {
                break
            }
        }

        # Формируем JSON объект
        printf "  {\"table\":\"%s\"", table_name

        if (where_condition != "") {
            gsub(/"/, "\\\"", where_condition)
            printf ",\"where\":\"%s\"", where_condition
        }

        if (limit_value != "") {
            printf ",\"limit\":%s", limit_value
        }

        if (orderby_value != "") {
            gsub(/"/, "\\\"", orderby_value)
            printf ",\"orderby\":\"%s\"", orderby_value
        }

        printf "}"
    }
    END {
        print "\n]"
    }
    ' "$CONFIG_FILE")

    if [[ "$MIGRATION_CONFIG_JSON" == "[" ]] || [[ "$MIGRATION_CONFIG_JSON" == "[]" ]]; then
        echo "[WARN] Awk метод не сработал, используем альтернативный..."

        MIGRATION_CONFIG_JSON="["
        FIRST=true

        TABLE_SECTION=$(grep -A10 "tables:" "$CONFIG_FILE")

        while IFS= read -r line; do
            if [[ "$line" =~ name:[[:space:]]*\"([^\"]+)\" ]]; then
                if [[ "$FIRST" == "false" ]]; then
                    MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON},"
                fi
                TABLE_NAME="${BASH_REMATCH[1]}"
                MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON}{\"table\":\"$TABLE_NAME\""
                FIRST="false"
            elif [[ -n "$TABLE_NAME" ]]; then
                if [[ "$line" =~ where:[[:space:]]*\"([^\"]+)\" ]]; then
                    WHERE="${BASH_REMATCH[1]}"
                    SAFE_WHERE=$(echo "$WHERE" | sed 's/"/\\"/g')
                    MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON},\"where\":\"$SAFE_WHERE\""
                elif [[ "$line" =~ limit:[[:space:]]*([0-9]+) ]]; then
                    LIMIT="${BASH_REMATCH[1]}"
                    MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON},\"limit\":$LIMIT"
                elif [[ "$line" =~ orderby:[[:space:]]*\"([^\"]+)\" ]]; then
                    ORDERBY="${BASH_REMATCH[1]}"
                    SAFE_ORDERBY=$(echo "$ORDERBY" | sed 's/"/\\"/g')
                    MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON},\"orderby\":\"$SAFE_ORDERBY\""
                elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ "$line" =~ ^[^[:space:]] ]]; then
                    MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON}}"
                    TABLE_NAME=""
                fi
            fi
        done <<< "$TABLE_SECTION"

        if [[ -n "$TABLE_NAME" ]]; then
            MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON}}"
        fi
        MIGRATION_CONFIG_JSON="${MIGRATION_CONFIG_JSON}]"
    fi

    if [[ "$MIGRATION_CONFIG_JSON" == "[" ]]; then
        MIGRATION_CONFIG_JSON="[]"
    fi

    echo "[INFO] === КОНФИГУРАЦИЯ ==="
    echo "[INFO] Исходная БД: $SOURCE_HOST:$SOURCE_PORT/$SOURCE_DATABASE"
    echo "[INFO] Целевая БД: $TARGET_HOST:$TARGET_PORT/$TARGET_DATABASE"
    echo "[INFO] Dump path: $DUMP_PATH"
    echo "[INFO] Потоков: $THREADS"
    echo "[INFO] Конфиг таблиц: $MIGRATION_CONFIG_JSON"
    echo "[INFO] ====================="

    echo "[INFO] Запускаем Go приложение..."

    echo "[INFO] Собираем Docker образ..."
    if docker build -t go-migrator .; then
        echo "[INFO] Запускаем контейнер (логи из Go будут видны ниже)..."

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
            -e "DUMP_FILE=$DUMP_PATH" \
            -e "MIGRATION_THREADS=$THREADS" \
            -e "MIGRATION_CONFIG_JSON=$MIGRATION_CONFIG_JSON" \
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