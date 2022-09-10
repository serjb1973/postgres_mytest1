--
-- PostgreSQL database dump
--

-- Dumped from database version 13.8 (Ubuntu 13.8-1.pgdg22.04+1)
-- Dumped by pg_dump version 13.8 (Ubuntu 13.8-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hh; Type: SCHEMA; Schema: -; Owner: mytestuser
--

CREATE SCHEMA hh;


ALTER SCHEMA hh OWNER TO mytestuser;

--
-- Name: get_report_01(); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.get_report_01() RETURNS text[]
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* Репорт 
* сводные данные по всем вакансиям с группироукой для вывода вилки ЗП
* форматирование для telegram
*/
v_page text;
v_record RECORD;
v_result text[];
BEGIN
/* шапка c форматированием для telegram*/
v_page:='Данные в локальной БД по всем специальностям%0A';
v_page:=v_page||format('|%-36s|%8s|%15s|%8s|%8s|', 'Регион', 'Кол-во', 'Уник. спец-ти', 'ЗП от', 'ЗП до')||'%0A';
v_page:=v_page||format('|%-36s|%8s|%15s|%8s|%8s|', rpad('-',36,'-'), rpad('-',8,'-'), rpad('-',15,'-'),rpad('-',8,'-'),rpad('-',8,'-'))||'%0A';
/* тело */
FOR v_record in (with t as (select area_name ,vac_name,
(case when val#>>'{salary,currency}' is null then 'RUR' else val#>>'{salary,currency}' end) as currency,
(val#>>'{salary,from}')::bigint salary_from,
(val#>>'{salary,to}')::bigint salary_to 
from vacancies order by 1)
select format('|%-36s|%8s|%15s|%8s|%8s|',(case when area_name is null then 'Всего' else area_name end),
count(*),
count(distinct vac_name),
min(salary_from)::bigint,
max(salary_to)::bigint)||'%0A' txt 
from t
group by GROUPING SETS(area_name,()))
	LOOP
	v_page:=v_page||v_record.txt;
	/* обходим ограничение на 4К символов в telegram */
	IF char_length(v_page)>3000 THEN
	/* добавляем форматирование для telegram и расширяем массив	*/
	v_page:='<pre>'||v_page||'</pre>';
	v_result:=v_result||v_page;
	v_page='';
	END IF;
	END LOOP;
/* добавляем форматирование для telegram */
v_page:='<pre>'||v_page||'</pre>';
v_result:=v_result||v_page;
return v_result;
END;
$$;


ALTER FUNCTION hh.get_report_01() OWNER TO mytestuser;

--
-- Name: get_report_02(bigint); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.get_report_02(p_mid bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* Репорт 
* дёргаем данные по любой первой вакансии из загруженных по запросу
* форматирование для telegram
*/
v_text text;
BEGIN
IF p_mid = 0 THEN
return '';
END IF;
select val->>'alternate_url' into v_text from public.vacancies where mid=p_mid limit 1;
return 'Для примера, ссылка на одну из найденных вакансий:%0A'||v_text;
END;
$$;


ALTER FUNCTION hh.get_report_02(p_mid bigint) OWNER TO mytestuser;

--
-- Name: get_response(text); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.get_response(p_search text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* запрашиваем вакансии через API сайта HH 
* получаем и сохраняем JSON с результатом поиска
*/
v_url jsonb:=public.get_params('hh_url');
v_params jsonb:=public.get_params('hh_params');
v_search jsonb:='{"text":"'||p_search||'"}';
v_response jsonb;
v_mid bigint;
BEGIN
/* собрали параметры с поисковой фразой (параметр вызова p_search) */
v_params:=v_params::jsonb||v_search::jsonb;
/* получили JSON с API сайта HH */
v_response:=hh.get_response(p_url=>v_url->>'url',p_params=>v_params::text);
/* сохранили JSON */
insert into public.messages(id,message) values (DEFAULT,v_response)  returning id into v_mid;
return v_mid;
END;
$$;


ALTER FUNCTION hh.get_response(p_search text) OWNER TO mytestuser;

--
-- Name: get_response(text, text); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.get_response(p_url text, p_params text) RETURNS jsonb
    LANGUAGE plpython3u
    AS $$
""" Получение данных от удалённого API """
import requests
import json
response = requests.get(p_url,json.loads(p_params))
js=response.text
response.close()
return js
$$;


ALTER FUNCTION hh.get_response(p_url text, p_params text) OWNER TO mytestuser;

--
-- Name: main(text); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.main(p_search text DEFAULT 'postgres'::text) RETURNS bigint[]
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* основная функция hh схемы для вызова снаружи
*/
v_mid bigint;
v_result_parse bigint[];
BEGIN
/* запросили файл JSON с вакансиями с HH */
v_mid:=hh.get_response(p_search);
/* разложили JSON в таблицу вакансий */
v_result_parse:=hh.parse_messages(p_mid=>v_mid::bigint);
/* формат вывода:
1 id JSON документа (таблица messages)
2 количество найденных вакансий всего на сайте HH
3 количество вакансий в JSON документе
4 количество загруженных вакансий (повторно не грузим) 
*/
return v_mid||v_result_parse;
END;
$$;


ALTER FUNCTION hh.main(p_search text) OWNER TO mytestuser;

--
-- Name: parse_messages(bigint); Type: FUNCTION; Schema: hh; Owner: mytestuser
--

CREATE FUNCTION hh.parse_messages(p_mid bigint) RETURNS bigint[]
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* JSON парсер
*/
v_json_source jsonb;
v_items jsonb;
v_item jsonb;
v_found bigint:=0;
v_rowcount bigint:=0;
BEGIN
/* выбираем загруженный JSON */
select message into v_json_source from public.messages where id=p_mid;
v_found = (v_json_source->>'found')::bigint;
/* если нет данных в JSON то выход */
IF v_found = 0 THEN
return array[0,0,0];
END IF;
v_items:=v_json_source#>'{items}';
/* цикл по массиву документов в JSON 
* с вставкой найденных вакансий в таблицу */
for v_item in select value from json_array_elements(v_items::json)
  LOOP
  BEGIN
  insert into public.vacancies(id,mid,val,area_name,vac_name) values ((v_item->>'id')::bigint,p_mid,v_item,v_item#>>'{area,name}',v_item->>'name');
  v_rowcount:=v_rowcount+1;
/* если вакансия есть в таблице не дублируем её */  
  EXCEPTION WHEN unique_violation THEN
  END;
  END LOOP;
/* формат вывода:
* 1 количество найденных вакансий всего на сайте HH
* 2 количество вакансий в JSON документе
* 3 количество загруженных вакансий (повторно не грузим) 
*/  
return array[v_found,jsonb_array_length(v_items),v_rowcount];
END;
$$;


ALTER FUNCTION hh.parse_messages(p_mid bigint) OWNER TO mytestuser;

--
-- PostgreSQL database dump complete
--

