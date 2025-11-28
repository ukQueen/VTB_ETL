package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "github.com/lib/pq"
)

type Config struct {
	SourceDB struct {
		Host     string
		Port     int
		Database string
		Username string
		Password string
		URL      string
	}

	TargetDB struct {
		Host     string
		Port     int
		Database string
		Username string
		Password string
		URL      string
	}

	Migration struct {
		Threads   int
		TableList []TableConfig
	}
}

type TableConfig struct {
	Table   string
	Columns []string
	Where   string
	Limit   int
	OrderBy string
}

type MigrationResult struct {
	TableName string
	Success   bool
	Error     string
	Duration  time.Duration
	RowsCount int
}

type Logger struct{}

func (logger *Logger) logInfo(message string) {
	fmt.Println("[INFO] " + message)
}

func (logger *Logger) logError(message string) {
	fmt.Println("[ERROR] " + message)
}

func loadConfigFromEnv() (*Config, error) {
	config := &Config{}

	config.SourceDB.Host = os.Getenv("SOURCE_DB_HOST")
	config.SourceDB.Port, _ = strconv.Atoi(os.Getenv("SOURCE_DB_PORT"))
	config.SourceDB.Database = os.Getenv("SOURCE_DB_NAME")
	config.SourceDB.Username = os.Getenv("SOURCE_DB_USERNAME")
	config.SourceDB.Password = os.Getenv("SOURCE_DB_PASSWORD")
	config.SourceDB.URL = os.Getenv("SOURCE_DB_URL")

	config.TargetDB.Host = os.Getenv("TARGET_DB_HOST")
	config.TargetDB.Port, _ = strconv.Atoi(os.Getenv("TARGET_DB_PORT"))
	config.TargetDB.Database = os.Getenv("TARGET_DB_NAME")
	config.TargetDB.Username = os.Getenv("TARGET_DB_USERNAME")
	config.TargetDB.Password = os.Getenv("TARGET_DB_PASSWORD")
	config.TargetDB.URL = os.Getenv("TARGET_DB_URL")

	if config.SourceDB.URL == "" {
		config.SourceDB.URL = fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=disable",
			config.SourceDB.Username,
			config.SourceDB.Password,
			config.SourceDB.Host,
			config.SourceDB.Port,
			config.SourceDB.Database)
	}

	if config.TargetDB.URL == "" {
		config.TargetDB.URL = fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=disable",
			config.TargetDB.Username,
			config.TargetDB.Password,
			config.TargetDB.Host,
			config.TargetDB.Port,
			config.TargetDB.Database)
	}

	config.Migration.Threads, _ = strconv.Atoi(os.Getenv("MIGRATION_THREADS"))
	config.Migration.TableList = parseTablesFromEnv()

	return config, nil
}

func parseTablesFromEnv() []TableConfig {
	var tables []TableConfig

	configJSON := os.Getenv("MIGRATION_CONFIG_JSON")
	if configJSON != "" {
		type JSONTableConfig struct {
			Table string `json:"table"`
			Where string `json:"where,omitempty"`
			Limit int    `json:"limit,omitempty"`
		}

		var jsonTables []JSONTableConfig
		if err := json.Unmarshal([]byte(configJSON), &jsonTables); err == nil {
			for _, jsonTable := range jsonTables {
				tables = append(tables, TableConfig{
					Table: jsonTable.Table,
					Where: jsonTable.Where,
					Limit: jsonTable.Limit,
				})
			}
			fmt.Printf("[INFO] Загружено %d таблиц из JSON конфига\n", len(tables))
		} else {
			fmt.Printf("[WARN] Ошибка парсинга MIGRATION_CONFIG_JSON: %v\n", err)
		}
	}

	if len(tables) == 0 {
		tablesEnv := os.Getenv("MIGRATION_TABLES")
		if tablesEnv != "" {
			tableNames := strings.FieldsFunc(tablesEnv, func(r rune) bool {
				return r == ',' || r == ' '
			})
			for _, tableName := range tableNames {
				tables = append(tables, TableConfig{Table: strings.TrimSpace(tableName)})
			}
			fmt.Printf("[INFO] Загружено %d таблиц из MIGRATION_TABLES\n", len(tables))
		}
	}

	return tables
}

func validateConfig(config *Config) error {
	if config.SourceDB.URL == "" {
		return fmt.Errorf("SOURCE_DB_URL is required")
	}
	if config.TargetDB.URL == "" {
		return fmt.Errorf("TARGET_DB_URL is required")
	}
	if len(config.Migration.TableList) == 0 {
		return fmt.Errorf("no tables to migrate")
	}
	return nil
}

func printConfig(config *Config, logger *Logger) {
	logger.logInfo("=== КОНФИГУРАЦИЯ МИГРАЦИИ ===")
	logger.logInfo("Режим: Прямая миграция")
	logger.logInfo(fmt.Sprintf("Исходная БД: %s", maskPassword(config.SourceDB.URL)))
	logger.logInfo(fmt.Sprintf("Целевая БД: %s", maskPassword(config.TargetDB.URL)))
	logger.logInfo(fmt.Sprintf("Потоков: %d", config.Migration.Threads))
	logger.logInfo(fmt.Sprintf("Таблиц для миграции: %d", len(config.Migration.TableList)))

	for i, table := range config.Migration.TableList {
		logger.logInfo(fmt.Sprintf("  %d. %s", i+1, table.Table))
		if table.Where != "" {
			logger.logInfo(fmt.Sprintf("     WHERE: %s", table.Where))
		}
		if table.Limit > 0 {
			logger.logInfo(fmt.Sprintf("     LIMIT: %d", table.Limit))
		}
		if table.OrderBy != "" {
			logger.logInfo(fmt.Sprintf("     ORDER BY: %s", table.OrderBy))
		}
	}
	logger.logInfo("==============================")
}

func maskPassword(url string) string {
	if strings.Contains(url, "@") {
		parts := strings.Split(url, "@")
		if len(parts) == 2 {
			authParts := strings.Split(parts[0], "://")
			if len(authParts) == 2 {
				credParts := strings.Split(authParts[1], ":")
				if len(credParts) == 2 {
					return fmt.Sprintf("%s://%s:****@%s", authParts[0], credParts[0], parts[1])
				}
			}
		}
	}
	return url
}

func connectToDB(config *Config) (*sql.DB, *sql.DB, error) {
	logger := &Logger{}

	logger.logInfo("Подключаемся к исходной БД...")
	sourceDB, err := sql.Open("postgres", config.SourceDB.URL)
	if err != nil {
		return nil, nil, fmt.Errorf("ошибка подключения к исходной БД: %v", err)
	}

	if err := sourceDB.Ping(); err != nil {
		sourceDB.Close()
		return nil, nil, fmt.Errorf("не удалось подключиться к исходной БД: %v", err)
	}
	logger.logInfo("Подключение к исходной БД установлено")

	logger.logInfo("Подключаемся к целевой БД...")
	targetDB, err := sql.Open("postgres", config.TargetDB.URL)
	if err != nil {
		sourceDB.Close()
		return nil, nil, fmt.Errorf("ошибка подключения к целевой БД: %v", err)
	}

	if err := targetDB.Ping(); err != nil {
		sourceDB.Close()
		targetDB.Close()
		return nil, nil, fmt.Errorf("не удалось подключиться к целевой БД: %v", err)
	}
	logger.logInfo("Подключение к целевой БД установлено")

	return sourceDB, targetDB, nil
}

func buildSelectQuery(tableConfig TableConfig) string {
	query := fmt.Sprintf("SELECT * FROM %s", tableConfig.Table)

	if tableConfig.Where != "" {
		query += " WHERE " + tableConfig.Where
	}

	if tableConfig.OrderBy != "" {
		query += " ORDER BY " + tableConfig.OrderBy
	}

	if tableConfig.Limit > 0 {
		query += fmt.Sprintf(" LIMIT %d", tableConfig.Limit)
	}

	return query
}

func migrateTable(tableConfig TableConfig, workerId int, config *Config) (int, error) {
	logger := &Logger{}
	logger.logInfo(fmt.Sprintf("Воркер %d: Мигрируем таблицу: %s", workerId, tableConfig.Table))

	sourceDB, targetDB, err := connectToDB(config)
	if err != nil {
		return 0, fmt.Errorf("ошибка подключения к БД: %v", err)
	}
	defer sourceDB.Close()
	defer targetDB.Close()

	// Формируем запрос с учетом условий
	query := buildSelectQuery(tableConfig)

	logger.logInfo(fmt.Sprintf("Воркер %d: SQL запрос: %s", workerId, query))

	rows, err := sourceDB.Query(query)
	if err != nil {
		return 0, fmt.Errorf("ошибка выполнения запроса: %v", err)
	}
	defer rows.Close()

	columns, err := rows.Columns()
	if err != nil {
		return 0, fmt.Errorf("ошибка получения колонок: %v", err)
	}

	values := make([]interface{}, len(columns))
	valuePtrs := make([]interface{}, len(columns))
	for i := range columns {
		valuePtrs[i] = &values[i]
	}

	rowsCount := 0

	placeholders := make([]string, len(columns))
	for i := range columns {
		placeholders[i] = fmt.Sprintf("$%d", i+1)
	}
	insertQuery := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)",
		tableConfig.Table,
		strings.Join(columns, ", "),
		strings.Join(placeholders, ", "))

	tx, err := targetDB.Begin()
	if err != nil {
		return 0, fmt.Errorf("ошибка начала транзакции: %v", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(insertQuery)
	if err != nil {
		return 0, fmt.Errorf("ошибка подготовки запроса: %v", err)
	}
	defer stmt.Close()

	for rows.Next() {
		err := rows.Scan(valuePtrs...)
		if err != nil {
			return rowsCount, fmt.Errorf("ошибка чтения строки: %v", err)
		}

		_, err = stmt.Exec(values...)
		if err != nil {
			return rowsCount, fmt.Errorf("ошибка вставки строки: %v", err)
		}

		rowsCount++
	}

	err = tx.Commit()
	if err != nil {
		return rowsCount, fmt.Errorf("ошибка коммита транзакции: %v", err)
	}

	if err = rows.Err(); err != nil {
		return rowsCount, fmt.Errorf("ошибка при итерации по строкам: %v", err)
	}

	logger.logInfo(fmt.Sprintf("Воркер %d: Перенесено %d строк из таблицы %s", workerId, rowsCount, tableConfig.Table))
	return rowsCount, nil
}

func worker(workerId int, jobs <-chan TableConfig, results chan<- MigrationResult, wg *sync.WaitGroup, config *Config) {
	defer wg.Done()
	for job := range jobs {
		startTime := time.Now()

		rowsCount, err := migrateTable(job, workerId, config)

		result := MigrationResult{
			TableName: job.Table,
			Duration:  time.Since(startTime),
			RowsCount: rowsCount,
		}

		if err != nil {
			result.Success = false
			result.Error = err.Error()
		} else {
			result.Success = true
		}

		results <- result
	}
}

func runParallelMigration(config *Config, logger *Logger) {
	logger.logInfo("Запускаем многопоточную миграцию")

	numWorkers := config.Migration.Threads
	if numWorkers <= 0 {
		numWorkers = 2
	}

	jobs := make(chan TableConfig, len(config.Migration.TableList))
	results := make(chan MigrationResult, len(config.Migration.TableList))

	var wg sync.WaitGroup

	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go worker(i+1, jobs, results, &wg, config)
	}

	for _, table := range config.Migration.TableList {
		jobs <- table
	}
	close(jobs)

	go func() {
		wg.Wait()
		close(results)
	}()

	successCount := 0
	failCount := 0
	totalRows := 0

	for result := range results {
		if result.Success {
			successCount++
			totalRows += result.RowsCount
			logger.logInfo(fmt.Sprintf("%s успешно (%d строк, %v)", result.TableName, result.RowsCount, result.Duration))
		} else {
			failCount++
			logger.logError(fmt.Sprintf("%s ошибка - %s (%v)", result.TableName, result.Error, result.Duration))
		}
	}

	logger.logInfo(fmt.Sprintf("Итог: %d успешно, %d с ошибками, всего строк: %d", successCount, failCount, totalRows))
}

func validateTablesExist(sourceDB *sql.DB, targetDB *sql.DB, tables []TableConfig, logger *Logger) error {
	var missingTables []string

	for _, tableConfig := range tables {
		logger.logInfo(fmt.Sprintf("Проверяем таблицу: %s", tableConfig.Table))

		// Проверяем в source БД
		var sourceExists bool
		err := sourceDB.QueryRow("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = $1)", tableConfig.Table).Scan(&sourceExists)
		if err != nil {
			return fmt.Errorf("ошибка проверки таблицы %s в source: %v", tableConfig.Table, err)
		}
		if !sourceExists {
			missingTables = append(missingTables, fmt.Sprintf("%s (в source БД)", tableConfig.Table))
			continue
		}

		// Проверяем в target БД
		var targetExists bool
		err = targetDB.QueryRow("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = $1)", tableConfig.Table).Scan(&targetExists)
		if err != nil {
			return fmt.Errorf("ошибка проверки таблицы %s в target: %v", tableConfig.Table, err)
		}
		if !targetExists {
			missingTables = append(missingTables, fmt.Sprintf("%s (в target БД)", tableConfig.Table))
			continue
		}

		logger.logInfo(fmt.Sprintf("Таблица %s найдена в обеих БД", tableConfig.Table))
	}

	if len(missingTables) > 0 {
		return fmt.Errorf("отсутствующие таблицы: %s", strings.Join(missingTables, ", "))
	}

	return nil
}

func main() {
	logger := &Logger{}

	logger.logInfo("Загрузка конфигурации из переменных окружения...")
	config, err := loadConfigFromEnv()
	if err != nil {
		logger.logError("Ошибка загрузки конфигурации: " + err.Error())
		os.Exit(1)
	}

	if err := validateConfig(config); err != nil {
		logger.logError("Ошибка валидации конфигурации: " + err.Error())
		os.Exit(1)
	}

	printConfig(config, logger)

	logger.logInfo("Подключаемся к БД для проверки...")
	sourceDB, targetDB, err := connectToDB(config)
	if err != nil {
		logger.logError("Ошибка подключения к БД: " + err.Error())
		os.Exit(1)
	}
	defer sourceDB.Close()
	defer targetDB.Close()

	logger.logInfo("Проверяем существование таблиц...")
	if err := validateTablesExist(sourceDB, targetDB, config.Migration.TableList, logger); err != nil {
		logger.logError("Ошибка проверки таблиц: " + err.Error())
		os.Exit(1)
	}
	logger.logInfo("Все таблицы проверены успешно")

	logger.logInfo("Запуск миграции...")
	startTime := time.Now()
	runParallelMigration(config, logger)
	duration := time.Since(startTime)

	logger.logInfo(fmt.Sprintf("Миграция завершена за %v", duration))
}
