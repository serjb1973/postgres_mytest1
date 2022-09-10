# Проект тестовый №1 postgresql
## _цель проекта - освоение plpgsql_
## Возможности
- Делаем запрос для поиска вакансии в HH
- Получаем информацию по запросу
- Получаем информацию из тестовой БД
### Технологии
PostgreSQL 13.8
### Установка проекта:
```
create user mytestuser with superuser password 'test';
create database mytestdb with owner mytestuser;
create schema extensions;
CREATE EXTENSION dblink SCHEMA extensions;
CREATE EXTENSION jsonb_plpython3u cascade SCHEMA extensions;
SHOW search_path;
ALTER DATABASE mytestdb SET search_path = "$user", public, extensions;
sudo -iu postgres psql -d mytestdb -U mytestuser < hh.sql
sudo -iu postgres psql -d mytestdb -U mytestuser < telegram.sql
sudo -iu postgres psql -d mytestdb -U mytestuser < public.sql
```
### Необходимо заполнить таблицу params
### например:
```
INSERT INTO public.params (name, value) VALUES ('hh_url', '{"url":"https://api.hh.ru/vacancies"}');
INSERT INTO public.params (name, value) VALUES ('telegram_url', '{"url":"https://api.telegram.org/ИД бота/"}');
INSERT INTO public.params (name, value) VALUES ('hh_params', '{"per_page":"10","page":"0","currency":"RUR"}');
INSERT INTO public.params (name, value) VALUES ('telegram_debug', '{"debug":"1"}');
INSERT INTO public.params (name, value) VALUES ('telegram_clear', '{"minutes":"60"}');
INSERT INTO public.params (name, value) VALUES ('telegram_offset', '{"offset": 1}');
```
### запуск:
```
sudo -iu postgres psql mytestdb -U mytestuser -c "call public.pmain(10,1000);" &
```

### Для демонстрации БД в cloud.yandex запущена и обслуживает запросы telegram bot:
https://t.me/serjb_resume_1_bot
### Автор
Сергей
