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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: get_params(character); Type: FUNCTION; Schema: public; Owner: mytestuser
--

CREATE FUNCTION public.get_params(p_name character) RETURNS json
    LANGUAGE sql
    AS $$
/* 
* вернуть значение параметра
*/
select value::json from params where name=p_name;
$$;


ALTER FUNCTION public.get_params(p_name character) OWNER TO mytestuser;

--
-- Name: pmain(integer, integer); Type: PROCEDURE; Schema: public; Owner: mytestuser
--

CREATE PROCEDURE public.pmain(p_sleep integer DEFAULT 60, p_count integer DEFAULT 30)
    LANGUAGE plpgsql
    AS $$
DECLARE
/* 
* основная процедура для вызова всего модуля
*/
v_telegram_set_result text;
v_rec_telegrams public.telegrams%rowtype;
v_message text;
v_result text;
v_result_arr bigint[];
v_report_01 text[];
v_page_01 text;
BEGIN
FOR i in 1..p_count
LOOP
/* чистим таблицу от устаревших необработанных запросов из телеграм */
perform telegram.clear();
/* запрашиваем сообщения для бота из телеграм */
select telegram.get() into v_telegram_set_result;
IF v_telegram_set_result='OK' THEN
	/* если сообщения есть то обрабатываем их по очереди от старого к новому */
	FOR v_rec_telegrams in 
	select * from public.telegrams where status_output is null order by update_id
	LOOP
		CASE 
		/* если команда боту /start */
		WHEN v_rec_telegrams.text='/start' THEN
		v_message:='Привет '||v_rec_telegrams.username||'!%0AВведите слово или выражения для поиска на HH.ru...';
		v_result:=telegram.send(v_rec_telegrams.id,v_message);
		/* если команда боту c /  */
		WHEN v_rec_telegrams.text like '/%' or v_rec_telegrams.text like '%\\%' THEN
		v_message:='Введите другое слово или выражения для поиска на HH.ru...';
		v_result:=telegram.send(v_rec_telegrams.id,v_message);
		ELSE
		/* если запрос на поиск вакансии то вызываем функцию схемы hh для поиска */
		select hh.main(v_rec_telegrams.text) into v_result_arr;
		v_message:='Найдено вакансий '||v_result_arr[2]::text||
		', из них на загрузку в БД '||v_result_arr[3]::text||
		', загружено '||v_result_arr[4]::text;
		IF v_result_arr[3]>v_result_arr[4] THEN
		v_message:=v_message||', остальные '||
		(v_result_arr[3]-v_result_arr[4])::text||' уже есть в БД.';
		END IF;
		/* отправляем результаты поиска в чат */
		v_result:=telegram.send(v_rec_telegrams.id,v_message);
		/* отправляем любую из найденных вакансий в чат */
		IF v_result_arr[4]>0 THEN
		v_result:=telegram.send(v_rec_telegrams.id,hh.get_report_02(v_result_arr[1]));
		END IF;
		/* отправляем репорт о состоянии БД в чат */
		v_report_01:=hh.get_report_01();
		FOREACH v_page_01 in ARRAY v_report_01
		LOOP
		v_result:=telegram.send(v_rec_telegrams.id,v_page_01);
		END LOOP;
		END CASE;
		commit;
	END LOOP;
END IF;
PERFORM pg_sleep(p_sleep);
END LOOP;
END;
$$;


ALTER PROCEDURE public.pmain(p_sleep integer, p_count integer) OWNER TO mytestuser;

--
-- Name: set_params(character, jsonb); Type: FUNCTION; Schema: public; Owner: mytestuser
--

CREATE FUNCTION public.set_params(p_name character, p_value jsonb) RETURNS integer
    LANGUAGE sql
    AS $$
/* 
* заменить значение параметра
*/
update public.params set value=p_value where name=p_name;
select 1;
$$;


ALTER FUNCTION public.set_params(p_name character, p_value jsonb) OWNER TO mytestuser;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    date_input timestamp with time zone DEFAULT CURRENT_TIMESTAMP(0) NOT NULL,
    message jsonb
);


ALTER TABLE public.messages OWNER TO mytestuser;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: mytestuser
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.messages_id_seq OWNER TO mytestuser;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mytestuser
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: params; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.params (
    name text NOT NULL,
    value json
);


ALTER TABLE public.params OWNER TO mytestuser;

--
-- Name: telegrams; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.telegrams (
    id bigint NOT NULL,
    update_id bigint NOT NULL,
    chat_id bigint NOT NULL,
    username text,
    text text,
    date_input timestamp with time zone DEFAULT CURRENT_TIMESTAMP(0) NOT NULL,
    date_output timestamp with time zone,
    message_output text,
    status_output text
);


ALTER TABLE public.telegrams OWNER TO mytestuser;

--
-- Name: telegrams_id_seq; Type: SEQUENCE; Schema: public; Owner: mytestuser
--

CREATE SEQUENCE public.telegrams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.telegrams_id_seq OWNER TO mytestuser;

--
-- Name: telegrams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mytestuser
--

ALTER SEQUENCE public.telegrams_id_seq OWNED BY public.telegrams.id;


--
-- Name: telegrams_log; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.telegrams_log (
    id bigint NOT NULL,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP(0) NOT NULL,
    is_input boolean DEFAULT true NOT NULL,
    note text,
    message text
);


ALTER TABLE public.telegrams_log OWNER TO mytestuser;

--
-- Name: telegrams_log_id_seq; Type: SEQUENCE; Schema: public; Owner: mytestuser
--

CREATE SEQUENCE public.telegrams_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.telegrams_log_id_seq OWNER TO mytestuser;

--
-- Name: telegrams_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mytestuser
--

ALTER SEQUENCE public.telegrams_log_id_seq OWNED BY public.telegrams_log.id;


--
-- Name: ttest; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.ttest (
    id bigint
);


ALTER TABLE public.ttest OWNER TO mytestuser;

--
-- Name: vacancies; Type: TABLE; Schema: public; Owner: mytestuser
--

CREATE TABLE public.vacancies (
    id bigint NOT NULL,
    mid bigint NOT NULL,
    area_name text,
    vac_name text NOT NULL,
    val jsonb
);


ALTER TABLE public.vacancies OWNER TO mytestuser;

--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: telegrams id; Type: DEFAULT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.telegrams ALTER COLUMN id SET DEFAULT nextval('public.telegrams_id_seq'::regclass);


--
-- Name: telegrams_log id; Type: DEFAULT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.telegrams_log ALTER COLUMN id SET DEFAULT nextval('public.telegrams_log_id_seq'::regclass);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: params params_pkey; Type: CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.params
    ADD CONSTRAINT params_pkey PRIMARY KEY (name);


--
-- Name: telegrams_log telegrams_log_pkey; Type: CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.telegrams_log
    ADD CONSTRAINT telegrams_log_pkey PRIMARY KEY (id);


--
-- Name: telegrams telegrams_pkey; Type: CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.telegrams
    ADD CONSTRAINT telegrams_pkey PRIMARY KEY (id);


--
-- Name: vacancies vacancies_pkey; Type: CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.vacancies
    ADD CONSTRAINT vacancies_pkey PRIMARY KEY (id);


--
-- Name: vacancies fk_vacancies_messages; Type: FK CONSTRAINT; Schema: public; Owner: mytestuser
--

ALTER TABLE ONLY public.vacancies
    ADD CONSTRAINT fk_vacancies_messages FOREIGN KEY (mid) REFERENCES public.messages(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

