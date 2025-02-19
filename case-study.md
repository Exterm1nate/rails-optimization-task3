# Оптимизация импорта

## Шаг 1

Изначальное время импорта для `small.json` -- 7.5 секунд.

Снача отрефакторим. 

Ruby-prof в отчете показывает какую-то ерунду, а Valgrind не хочет работать с командой rake.

Потому ориентироваться будем в основном на PgHero и оптимизировать запросы к БД.
Видно, что много запросов выполняется для поиска уже созданных записей, потому первый шаг оптимизации заключается
в уменьшении количества запросов к БД путем сохранения уже созданных записей (а вернее - их id) в хэши.

По итогу избавились от большей части ненужных поисковых запросов, но некоторые все равно остались.

После оптимизации для `small.json` -- 3.9 секунд.

## Шаг 2

Изначально для `medium.json` -- 27.5 секунд.

Для поиска мест вызовов ненужных запросов включим логгирование.
По нему становится понятно, что все лишние запросы выполняются во время создания Trip. 
Для решения данной проблемы, а также проблемы создания записей по одной, воспользуемся гемом `activerecord-import`.
Для простоты алгоритма сначала реализуем импорт только для Trip.

После оптимизации для `medium.json` -- 5.4 секунд, для `large.json` -- 19 секунд. Цель достигнута.

# Оптимизация TripsController#index

## Шаг 1

Изначально для 1004 рейсов -- 21 секунда.

`bullet` показывает, что присутствует проблема `N + 1` (на `bus`). 
`PgHero` также фиксирует 648 запросов к таблице `buses` и 648 к `services`.

```sql
SELECT  "buses".* FROM "buses" WHERE "buses"."id" = $1 LIMIT $2
```

```sql
SELECT "services".* FROM "services" INNER JOIN "buses_services" ON "services"."id" = "buses_services"."service_id" WHERE "buses_services"."bus_id" = $1
```

Добавим `includes(bus: :services)`

После оптимизации -- 12.8 секунд

## Шаг 2

По отчету `PgHero` видно, что лишний раз вызывается

```sql
SELECT COUNT(*) FROM "trips" WHERE "trips"."from_id" = $1 AND "trips"."to_id" = $2
```

Вместо `count` вызовем ~~size~~ `length`.

Также, `PgHero` предлагает добавить индексы.

`CREATE INDEX CONCURRENTLY ON buses_services (bus_id)`

`CREATE INDEX CONCURRENTLY ON trips (from_id, to_id)`

Добавив индексы, выполним `VACUUM FULL`, чтобы убедиться в применении индексов.

Итого получается 6 запросов:
2 -- загрузка City
1 -- загрузка Trip
1 -- загрузка Bus
1 -- загрузка BusesService
1 -- загрузка Service

После оптимизации -- 12.8 секунд (ничего не изменилось, т.к. SQL-запросы занимали малую часть всего времени обработки запроса)

## Шаг 3

После оптимизации SQL-запросов займемся оптимизацией вычислений во вьюхах.

Целую часть и остаток при делении будем вычислять единоразово с помощью метода `divmod` и мемоизировать.

`rack-mini-profiler` показывает, что много времени занимает рендеринг паршелов. Уберем их вызов, вставив их содержимое
непосредственно в `index.erb`

После оптимизации -- 1.6 секунд
