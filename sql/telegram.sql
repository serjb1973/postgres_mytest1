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
-- Name: telegram; Type: SCHEMA; Schema: -; Owner: mytestuser
--

CREATE SCHEMA telegram;


ALTER SCHEMA telegram OWNER TO mytestuser;

--
-- Name: clear(); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.clear() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* очистка необработанных запросов старше заданного интервала
*/
v_interval bigint:=(public.get_params('telegram_clear')->>'minutes')::bigint;
BEGIN
update public.telegrams 
set status_output='CLEAR',date_output=current_timestamp(0)
where status_output is null
and current_timestamp>date_input + v_interval * interval '1 minute';
return 1;
END;
$$;


ALTER FUNCTION telegram.clear() OWNER TO mytestuser;

--
-- Name: get(); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.get() RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
/*
* чтение из телеграм чата и сохранение сообщений
*/
v_offset text:=public.get_params('telegram_offset')->>'offset';
v_url text:=public.get_params('telegram_url')->>'url';
v_message jsonb;
v_items jsonb;
v_item jsonb;
v_update_id text;
v_temp integer;
BEGIN
/* чтение всех сообщений из api telegram */
v_message:=telegram.get(p_url=>v_url,p_offset=>v_offset);
PERFORM telegram.log(true,v_message::text,'offset='||v_offset);
IF v_message->>'ok'!='true' THEN
return 'ERROR';
END IF;
/* выбираем массив сообщений из JSON */
v_items:=v_message->'result';
IF json_array_length(v_items::json) = 0 THEN
return 'NULL';
END IF;
/* временная таблица для вычисления максимального ИД сообщений */
drop table if exists my_temp_01;
create temporary table my_temp_01(update_id bigint) on commit preserve rows;
delete from my_temp_01;
/* цикл по массиву сообщений */
FOR v_item in select * from json_array_elements(v_items::json)
LOOP
	IF jsonb_path_exists(v_item,'$.message[*]') THEN
	insert into public.telegrams(update_id,chat_id,username,text) 
		values ((v_item->>'update_id')::bigint,(v_item#>>'{message,chat,id}')::bigint,
				(v_item#>>'{message,chat,first_name}'),(v_item#>>'{message,text}'));
	END IF;			
	--RAISE NOTICE 'mytest 4 % ', (v_item->>'update_id');
	insert into my_temp_01(update_id) values ((v_item->>'update_id')::bigint);
END LOOP;
/* определяем макимальный ИД сообщений */
select (max(update_id)+1)::text into v_update_id from my_temp_01;
drop table if exists my_temp_01;
/* обновляем ИД сообщений telegram чтобы не читать сообщения повторно */
v_temp:=public.set_params(p_name=>'telegram_offset',
						  p_value=>jsonb_set(public.get_params('telegram_offset')::jsonb,'{offset}',v_update_id::jsonb));			  
return 'OK';
END;
$_$;


ALTER FUNCTION telegram.get() OWNER TO mytestuser;

--
-- Name: get(text, text); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.get(p_url text, p_offset text) RETURNS jsonb
    LANGUAGE plpython3u
    AS $$
""" получение сообщения из чатов telegram """
import requests
import json
url = p_url+'getUpdates'
response = requests.get(url,params={'offset':p_offset})
js=response.text
response.close()
return js
$$;


ALTER FUNCTION telegram.get(p_url text, p_offset text) OWNER TO mytestuser;

--
-- Name: log(boolean, text, text); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.log(p_is_input boolean, p_message text, p_note text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* доп логирование включаю при необходимости "разбора полётов"
*/
v_debug text:=public.get_params('telegram_debug')->>'debug';
v_insert_text text:='insert into public.telegrams_log(is_input,message,note) values ';
BEGIN
IF v_debug!='1' THEN
return 0;
END IF;
v_insert_text:=v_insert_text||'('||p_is_input::text||','''||p_message::text||''','''||p_note||''')';
/* автономная транзакция */
PERFORM dblink_exec('dbname=' || current_database(), v_insert_text);
return 1;
END;
$$;


ALTER FUNCTION telegram.log(p_is_input boolean, p_message text, p_note text) OWNER TO mytestuser;

--
-- Name: send(bigint, text); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.send(p_id bigint, p_message text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* отправка сообщений в чат телеграм
*/
v_url text:=public.get_params('telegram_url')->>'url';
v_result json;
v_chat_id bigint;
BEGIN
select chat_id into v_chat_id from public.telegrams  where id=p_id;
PERFORM telegram.log(false,p_message,'chat_id='||v_chat_id::text);
/* отправка сообщения */
v_result:=telegram.send(p_url=>v_url,p_chat_id=>v_chat_id::text,p_message=>p_message);
PERFORM telegram.log(true,v_result::text,'chat_id='||v_chat_id::text);
/* если ошибка то фиксируем в таблице статус */
IF v_result->>'ok'!='true' THEN
update public.telegrams 
set status_output='ERROR',date_output=current_timestamp(0)
where status_output is null and chat_id=v_chat_id;
END IF;
/* фиксируем в таблице статус и часть ответа */
update public.telegrams 
set status_output='SEND',date_output=current_timestamp(0),message_output=p_message
where status_output is null and id=p_id;
return 'OK';
END;
$$;


ALTER FUNCTION telegram.send(p_id bigint, p_message text) OWNER TO mytestuser;

--
-- Name: send(text, text, text); Type: FUNCTION; Schema: telegram; Owner: mytestuser
--

CREATE FUNCTION telegram.send(p_url text, p_chat_id text, p_message text) RETURNS jsonb
    LANGUAGE plpython3u
    AS $$
""" отправка сообщения в чат telegram """
import requests
import json
import urllib.parse
url = p_url+'sendMessage'
text=urllib.parse.unquote(p_message)
response = requests.get(url,params={'parse_mode':'HTML','chat_id':p_chat_id,'text':text})
js=response.text
response.close()
return js
$$;


ALTER FUNCTION telegram.send(p_url text, p_chat_id text, p_message text) OWNER TO mytestuser;

--
-- PostgreSQL database dump complete
--

