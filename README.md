# Проект тестовый №1 postgresql
## _цель проекта - освоение plpgsql_
## Возможности
- Делаем запрос для поиска вакансии в HH
- Получаем информацию по запросу
- Получаем информацию из тестовой БД
### Технологии
- PostgreSQL 13.8
- Ubuntu 22.04
### Установка проекта:
```
sudo apt-get install postgresql-14 postgresql-server-dev-14 postgresql-contrib-14 postgresql-plpython3-14
sudo -iu postgres psql
create user mytestuser with superuser password 'test';
create database mytestdb with owner mytestuser;
\c mytestdb mytestuser
create schema extensions;
create extension dblink schema extensions;
create extension jsonb_plpython3u cascade schema extensions;
show search_path;
alter database mytestdb set search_path = "$user", public, extensions;
\q
sudo -iu postgres psql -d mytestdb -u mytestuser < hh.sql
sudo -iu postgres psql -d mytestdb -u mytestuser < telegram.sql
sudo -iu postgres psql -d mytestdb -u mytestuser < public.sql
```
### Необходимо заполнить таблицу params
### например:
```
INSERT INTO public.params (name, value) VALUES ('hh_url', '{"url":"https://api.hh.ru/vacancies"}');
INSERT INTO public.params (name, value) VALUES ('telegram_url', '{"url":"https://api.telegram.org/"token for bot"/"}');
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
