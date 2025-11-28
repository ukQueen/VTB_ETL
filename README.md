### запуск

```aiignore
chmod +x script.sh
./script.sh config.yml
```

### config.yml

```aiignore
source:                         <- настройкеи отправляющей бд
  host: "host.docker.internal"  <- хост
  port: 5432                    <-порт
  database: "vtb_etl"           <- название базы
  username: "postgres"          <- пользователь
  password: "Qwert12d67AMr8"    <- пароль

target:                         <- настройкеи отправляющей бд
  host: "host.docker.internal"  <- хост
  port: 5432                    <-порт
  database: "vtb_etl_2"         <- название базы
  username: "postgres"          <- пользователь
  password: "Atreu1234vsds5678" <- пароль        

migration:                  
  threads: 4                    <- количество потоков
  tables:                       <- какие баблицы нужно мигрировать 
    - name: "universities"         и по каким правилам
      where: "university_id < 3"
      limit: 10
    - name: "faculties"
      limit: 50
    - name: "departments"
      where: "department_id = 10"

  roles:                        <- роли для миграции
    mode: "include"             <- "include" -- вклчить; "exlude" -- исключить
    list:
      - name: "userrrr"         <- название юзера
        table_privileges:       <- перечисление названий таблиц и привелегий для них
          - table: "universities"
            permissions: [ "SELECT", "INSERT", "UPDATE", "DELETE" ]




```