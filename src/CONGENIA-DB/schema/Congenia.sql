-- ============================================================
-- CONGENIA - esquema consolidado (pg_dump --schema-only)
-- Generado desde CONGENIA-M1-SERVER de59065 (2026-10-18), migracion 18_cie10_empty_suggestion_correction.sql
-- Es una foto para documentacion: para crear o migrar una base usa
-- CONGENIA-M1-SERVER/db/init (servicio migrate / make migrate).
-- ============================================================
--
-- PostgreSQL database dump
--

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

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
-- Name: keycloak; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA keycloak;

--
-- Name: auditoria_evento_encadenar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auditoria_evento_encadenar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  anterior char(64);
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('congenia.auditoria_evento'));
  NEW.secuencia := nextval('auditoria_evento_secuencia_seq');
  NEW.fecha_hora := clock_timestamp();
  SELECT hash_entrada_actual INTO anterior
  FROM auditoria_evento
  ORDER BY secuencia DESC
  LIMIT 1;
  NEW.hash_entrada_anterior := COALESCE(anterior, repeat('0', 64));
  NEW.hash_entrada_actual := auditoria_evento_hash(NEW);
  RETURN NEW;
END $$;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria_evento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria_evento (
    evento_id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid,
    tipo_evento character varying(50) NOT NULL,
    entidad_tipo character varying(50),
    entidad_id uuid,
    ip_origen character varying(45) NOT NULL,
    user_agent character varying(500),
    session_id character varying(100),
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    resultado character varying(20) NOT NULL,
    detalle_json jsonb,
    hash_entrada_anterior character(64),
    hash_entrada_actual character(64) NOT NULL,
    secuencia bigint NOT NULL,
    actor_sub character varying(100),
    actor_username character varying(200),
    actor_roles text[],
    id_tenant integer,
    http_method character varying(10),
    ruta character varying(300),
    status_code smallint,
    request_id character varying(100)
);

--
-- Name: COLUMN auditoria_evento.usuario_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.usuario_id IS 'NULL si el evento es previo a autenticación';

--
-- Name: COLUMN auditoria_evento.tipo_evento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.tipo_evento IS 'FK a tipo_evento_catalogo';

--
-- Name: COLUMN auditoria_evento.entidad_tipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.entidad_tipo IS 'Ficha | Consentimiento | Signo | Examen | Sesion';

--
-- Name: COLUMN auditoria_evento.entidad_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.entidad_id IS 'ID del objeto afectado';

--
-- Name: COLUMN auditoria_evento.resultado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.resultado IS 'EXITOSO | FALLIDO | DENEGADO';

--
-- Name: COLUMN auditoria_evento.detalle_json; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.detalle_json IS 'Contexto adicional estructurado por tipo de evento';

--
-- Name: COLUMN auditoria_evento.hash_entrada_anterior; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.hash_entrada_anterior IS 'hash_entrada_actual de la fila con la secuencia previa. Genesis: 64 ceros';

--
-- Name: COLUMN auditoria_evento.hash_entrada_actual; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.hash_entrada_actual IS 'auditoria_evento_hash(fila): SHA-256 de los campos canonicos + hash_entrada_anterior';

--
-- Name: COLUMN auditoria_evento.secuencia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.secuencia IS 'Orden total de la cadena. Lo asigna el trigger, no la aplicacion';

--
-- Name: COLUMN auditoria_evento.actor_sub; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.actor_sub IS 'Subject de Keycloak, client:<system_id> o system:<servicio>';

--
-- Name: COLUMN auditoria_evento.ruta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_evento.ruta IS 'Plantilla de la ruta (ej: /api/v1/fichas/:id), nunca la URL con identificadores';

--
-- Name: auditoria_evento_hash(public.auditoria_evento); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auditoria_evento_hash(e public.auditoria_evento) RETURNS character
    LANGUAGE sql STABLE
    AS $$
  SELECT encode(sha256(convert_to(jsonb_build_array(
    e.secuencia,
    to_char(e.fecha_hora AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    e.evento_id,
    e.tipo_evento,
    e.resultado,
    e.usuario_id,
    e.actor_sub,
    e.actor_username,
    e.actor_roles,
    e.id_tenant,
    e.entidad_tipo,
    e.entidad_id,
    e.ip_origen,
    e.user_agent,
    e.session_id,
    e.http_method,
    e.ruta,
    e.status_code,
    e.request_id,
    e.detalle_json,
    e.hash_entrada_anterior
  )::text, 'UTF8')), 'hex')
$$;

--
-- Name: bloquear_modificacion_auditoria(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bloquear_modificacion_auditoria() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'La tabla % es de solo insercion: % no esta permitido', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'insufficient_privilege';
END $$;

--
-- Name: ficha_provisional_no_truncate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ficha_provisional_no_truncate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'ficha_provisional no admite TRUNCATE';
END;
$$;

--
-- Name: ficha_provisional_validar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ficha_provisional_validar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'ficha_provisional no admite DELETE: usar estado DESCARTADA';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.estado <> 'PENDIENTE' THEN
      RAISE EXCEPTION 'Una ficha provisional nace en estado PENDIENTE';
    END IF;
    -- La fila apunta a una ficha raiz del mismo tenant cuya HC es la provisional.
    IF NOT EXISTS (
      SELECT 1
      FROM ficha_clinica f
      WHERE f.ficha_id = NEW.ficha_raiz_id
        AND f.ficha_raiz_id = f.ficha_id
        AND f.id_tenant = NEW.id_tenant
        AND f.historia_clinica = NEW.historia_clinica_provisional
    ) THEN
      RAISE EXCEPTION 'La ficha % no es una ficha raiz del tenant % con historia clinica %',
        NEW.ficha_raiz_id, NEW.id_tenant, NEW.historia_clinica_provisional;
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF OLD.estado IN ('CONSOLIDADA', 'DESCARTADA') THEN
    RAISE EXCEPTION 'La ficha provisional % ya esta resuelta (%)', OLD.ficha_raiz_id, OLD.estado;
  END IF;

  IF NEW.ficha_raiz_id IS DISTINCT FROM OLD.ficha_raiz_id
     OR NEW.id_tenant IS DISTINCT FROM OLD.id_tenant
     OR NEW.historia_clinica_referida IS DISTINCT FROM OLD.historia_clinica_referida
     OR NEW.historia_clinica_provisional IS DISTINCT FROM OLD.historia_clinica_provisional
     OR NEW.creado_por IS DISTINCT FROM OLD.creado_por
     OR NEW.fecha_creacion IS DISTINCT FROM OLD.fecha_creacion THEN
    RAISE EXCEPTION 'Los datos de origen de una ficha provisional no se modifican';
  END IF;

  -- La adenda de consolidacion es una version de la misma ficha raiz y lleva la HC real.
  IF NEW.ficha_consolidada_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM ficha_clinica f
    WHERE f.ficha_id = NEW.ficha_consolidada_id
      AND f.ficha_raiz_id = NEW.ficha_raiz_id
      AND f.id_tenant = NEW.id_tenant
      AND f.historia_clinica = NEW.historia_clinica_real
  ) THEN
    RAISE EXCEPTION 'La ficha % no es una version de % con historia clinica %',
      NEW.ficha_consolidada_id, NEW.ficha_raiz_id, NEW.historia_clinica_real;
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: verificar_cadena_auditoria(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_cadena_auditoria(desde_secuencia bigint DEFAULT 0) RETURNS TABLE(ok boolean, filas_verificadas bigint, primera_secuencia_rota bigint, motivo text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  r auditoria_evento;
  anterior char(64);
  n bigint := 0;
BEGIN
  IF desde_secuencia > 0 THEN
    SELECT a.hash_entrada_actual INTO anterior
    FROM auditoria_evento a
    WHERE a.secuencia < desde_secuencia
    ORDER BY a.secuencia DESC
    LIMIT 1;
  END IF;
  anterior := COALESCE(anterior, repeat('0', 64));

  FOR r IN SELECT * FROM auditoria_evento a WHERE a.secuencia >= desde_secuencia ORDER BY a.secuencia LOOP
    n := n + 1;
    IF r.hash_entrada_anterior IS DISTINCT FROM anterior THEN
      RETURN QUERY SELECT false, n, r.secuencia, 'hash_entrada_anterior no coincide con la fila previa'::text;
      RETURN;
    END IF;
    IF r.hash_entrada_actual IS DISTINCT FROM auditoria_evento_hash(r) THEN
      RETURN QUERY SELECT false, n, r.secuencia, 'hash_entrada_actual no coincide con el contenido de la fila'::text;
      RETURN;
    END IF;
    anterior := r.hash_entrada_actual;
  END LOOP;

  RETURN QUERY SELECT true, n, NULL::bigint, NULL::text;
END $$;

--
-- Name: asistencia_parto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asistencia_parto (
    asistencia_parto_id smallint NOT NULL,
    nombre character varying(100) NOT NULL
);

--
-- Name: auditoria_evento_secuencia_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auditoria_evento_secuencia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: auditoria_evento_secuencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auditoria_evento_secuencia_seq OWNED BY public.auditoria_evento.secuencia;

--
-- Name: cie10_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_catalogo (
    codigo_interno character varying NOT NULL,
    codigo character varying(8) NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    importado_en timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: cie10_clausula; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_clausula (
    version character varying(40) NOT NULL,
    texto text NOT NULL,
    activa boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: cie10_decision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_decision (
    codigo_traductor character varying NOT NULL,
    decision character varying(10) NOT NULL,
    codigo_final character varying(8) NOT NULL,
    codigo_interno_catalogo character varying,
    comentario character varying(300),
    posicion smallint,
    sugerencias_mostradas smallint NOT NULL,
    revisor_id character varying NOT NULL,
    revisor_nombre character varying(200) NOT NULL,
    decidido_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cie10_decision_decision_check CHECK (((decision)::text = ANY ((ARRAY['ACEPTADA'::character varying, 'RECHAZADA'::character varying])::text[])))
);

--
-- Name: cie10_decision_historial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_decision_historial (
    historial_id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo_traductor character varying NOT NULL,
    accion character varying(20) NOT NULL,
    decision_anterior jsonb,
    decision_nueva jsonb NOT NULL,
    revisor_id character varying NOT NULL,
    fecha_evento timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cie10_decision_historial_accion_check CHECK (((accion)::text = ANY ((ARRAY['CREATED'::character varying, 'UPDATED'::character varying])::text[])))
);

--
-- Name: cie10_lote_confirmacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_lote_confirmacion (
    run_id uuid NOT NULL,
    clausula_version character varying(40) NOT NULL,
    aceptada_por character varying NOT NULL,
    aceptada_en timestamp with time zone DEFAULT now() NOT NULL,
    confirmada_por character varying,
    confirmada_en timestamp with time zone,
    total_registros integer,
    csv_object_key text,
    csv_sha256 character(64)
);

--
-- Name: cie10_rag_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_rag_catalogo (
    rag_version character varying(80) NOT NULL,
    codigo character varying(8) NOT NULL,
    descripcion text NOT NULL,
    codigo_interno character varying,
    en_catalogo_institucional boolean NOT NULL,
    en_referencia_externa boolean NOT NULL,
    descripcion_normalizada text,
    nivel smallint,
    parent_codigo character varying(8),
    ancestros jsonb DEFAULT '[]'::jsonb NOT NULL,
    source character varying(120),
    texto_busqueda_normalizado text
);

--
-- Name: cie10_rag_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_rag_version (
    rag_version character varying(80) NOT NULL,
    estado character varying(20) DEFAULT 'BUILDING'::character varying NOT NULL,
    institutional_sha256 character(64) NOT NULL,
    reference_sha256 character(64),
    reference_commit character varying(64),
    embedding_model character varying(100) NOT NULL,
    embedding_dimensions integer NOT NULL,
    vector_count integer DEFAULT 0 NOT NULL,
    metadata_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    activated_at timestamp with time zone,
    CONSTRAINT cie10_rag_version_embedding_dimensions_check CHECK (((embedding_dimensions >= 1) AND (embedding_dimensions <= 4096))),
    CONSTRAINT cie10_rag_version_estado_check CHECK (((estado)::text = ANY ((ARRAY['BUILDING'::character varying, 'READY'::character varying, 'ACTIVE'::character varying, 'FAILED'::character varying, 'ARCHIVED'::character varying])::text[])))
);

--
-- Name: cie10_revision_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_revision_item (
    run_id uuid NOT NULL,
    codigo_traductor character varying NOT NULL,
    codigo_final character varying(8) NOT NULL,
    comentario character varying(300),
    corregido boolean DEFAULT false NOT NULL,
    revisor_id character varying NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    posicion smallint,
    sugerencias_mostradas smallint,
    CONSTRAINT cie10_revision_item_selection_chk CHECK ((((corregido = true) AND (posicion IS NULL) AND ((sugerencias_mostradas IS NULL) OR ((sugerencias_mostradas >= 0) AND (sugerencias_mostradas <= 5)))) OR ((corregido = false) AND ((posicion >= 1) AND (posicion <= 5)) AND ((sugerencias_mostradas >= posicion) AND (sugerencias_mostradas <= 5)))))
);

--
-- Name: cie10_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_run (
    run_id uuid DEFAULT gen_random_uuid() NOT NULL,
    estado character varying(20) DEFAULT 'RUNNING'::character varying NOT NULL,
    source_catalog_uri text NOT NULL,
    source_translator_uri text NOT NULL,
    model character varying(100) NOT NULL,
    prompt_version character varying(50) NOT NULL,
    max_records integer,
    processed_count integer DEFAULT 0 NOT NULL,
    suggestion_count integer DEFAULT 0 NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    metadata_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    cached_input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    reasoning_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    api_call_count integer DEFAULT 0 NOT NULL,
    rag_version character varying(80),
    periodo character(7),
    CONSTRAINT cie10_run_estado_check CHECK (((estado)::text = ANY ((ARRAY['RUNNING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT cie10_run_periodo_chk CHECK (((periodo IS NULL) OR (periodo ~ '^\d{4}-(0[1-9]|1[0-2])$'::text)))
);

--
-- Name: cie10_sugerencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_sugerencia (
    codigo_traductor character varying NOT NULL,
    run_id uuid NOT NULL,
    diagnostico text NOT NULL,
    cie10_original character varying,
    ai_status character varying(40) DEFAULT 'suggestions'::character varying NOT NULL,
    sugerencias jsonb DEFAULT '[]'::jsonb NOT NULL,
    razonamiento_clinico text,
    error text,
    modelo character varying(100) NOT NULL,
    procesado_en timestamp with time zone DEFAULT now() NOT NULL,
    input_tokens bigint DEFAULT 0 NOT NULL,
    cached_input_tokens bigint DEFAULT 0 NOT NULL,
    output_tokens bigint DEFAULT 0 NOT NULL,
    reasoning_tokens bigint DEFAULT 0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    api_call_count integer DEFAULT 0 NOT NULL,
    rag_version character varying(80),
    input_sha256 character(64),
    CONSTRAINT cie10_sugerencia_ai_status_check CHECK (((ai_status)::text = ANY ((ARRAY['suggestions'::character varying, 'insufficient_information'::character varying, 'error'::character varying])::text[])))
);

--
-- Name: consentimiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consentimiento (
    consentimiento_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    medico_id uuid NOT NULL,
    tipo_firmante character varying(50) NOT NULL,
    nombre_firmante character varying(200),
    idioma_consentimiento character varying(20) NOT NULL,
    aceptacion_terminos boolean NOT NULL,
    aceptacion_contacto boolean,
    fecha_hora_aceptacion timestamp with time zone NOT NULL,
    firma_evidencia_tecnica jsonb NOT NULL,
    firma_png_ref character varying(500),
    pdf_ref character varying(500),
    pdf_hash_sha256 character(64) NOT NULL,
    firma_png_hash_sha256 character(64) NOT NULL,
    json_hash_sha256 character(64) NOT NULL,
    ip_dispositivo character varying(45) NOT NULL,
    session_id character varying(100),
    estado_consentimiento character varying(20) DEFAULT 'VIGENTE'::character varying NOT NULL,
    anulado_por_id uuid,
    fecha_anulacion timestamp with time zone
);

--
-- Name: COLUMN consentimiento.tipo_firmante; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.tipo_firmante IS 'PADRE | MADRE | TUTOR | REPRESENTANTE_LEGAL';

--
-- Name: COLUMN consentimiento.idioma_consentimiento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.idioma_consentimiento IS 'ESPANOL | QEQCHI | IXIL';

--
-- Name: COLUMN consentimiento.aceptacion_terminos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.aceptacion_terminos IS 'Siempre TRUE para persistir. Constraint a nivel de app y BD.';

--
-- Name: COLUMN consentimiento.fecha_hora_aceptacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.fecha_hora_aceptacion IS 'NTP del servidor. Nunca hora del cliente.';

--
-- Name: COLUMN consentimiento.firma_evidencia_tecnica; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.firma_evidencia_tecnica IS 'Metadatos de la captura (timestamp, userAgent, canvasHash, version legal) y declaraciones aceptadas. Nunca la imagen ni el trazo de la firma.';

--
-- Name: COLUMN consentimiento.firma_png_ref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.firma_png_ref IS 'Clave S3 del PNG de la firma, en el bucket de documentos.';

--
-- Name: COLUMN consentimiento.firma_png_hash_sha256; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.firma_png_hash_sha256 IS 'SHA-256 de los bytes del PNG de la firma. El worker lo verifica antes de generar el PDF.';

--
-- Name: COLUMN consentimiento.json_hash_sha256; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.json_hash_sha256 IS 'SHA-256 de firma_evidencia_tecnica serializada como JSON canonico (claves ordenadas, sin espacios).';

--
-- Name: COLUMN consentimiento.ip_dispositivo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.ip_dispositivo IS 'IPv4 o IPv6';

--
-- Name: COLUMN consentimiento.estado_consentimiento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.consentimiento.estado_consentimiento IS 'VIGENTE | ANULADO';

--
-- Name: datos_adicionales_ficha; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datos_adicionales_ficha (
    ficha_id uuid NOT NULL,
    referido_de_id smallint,
    asistencia_parto_id smallint,
    familiares_afectos boolean DEFAULT false NOT NULL,
    personas_hogar_menores smallint DEFAULT 0,
    personas_hogar_adultos smallint DEFAULT 0,
    comunidad_afectada character varying(20),
    sexo_id smallint
);

--
-- Name: COLUMN datos_adicionales_ficha.comunidad_afectada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.datos_adicionales_ficha.comunidad_afectada IS 'SI | NO | DESCONOCIDO';

--
-- Name: examen_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.examen_catalogo (
    examen_catalogo_id integer NOT NULL,
    nombre_normalizado character varying(200) NOT NULL,
    tipo character varying(50),
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: COLUMN examen_catalogo.tipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.examen_catalogo.tipo IS 'GENETICO | IMAGEN | LABORATORIO | FUNCIONAL';

--
-- Name: examen_catalogo_examen_catalogo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.examen_catalogo_examen_catalogo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: examen_catalogo_examen_catalogo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.examen_catalogo_examen_catalogo_id_seq OWNED BY public.examen_catalogo.examen_catalogo_id;

--
-- Name: examen_ficha; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.examen_ficha (
    examen_ficha_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    examen_texto_libre character varying(300) NOT NULL,
    imagen_bucket_ref character varying(500),
    imagen_hash_sha256 character(64),
    fecha_registro timestamp with time zone DEFAULT now() NOT NULL,
    registrado_por uuid NOT NULL,
    added_in_revision boolean DEFAULT false NOT NULL,
    replaces_examen_id uuid
);

--
-- Name: COLUMN examen_ficha.examen_texto_libre; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.examen_ficha.examen_texto_libre IS 'Texto libre ingresado por el médico';

--
-- Name: familiar_afectado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.familiar_afectado (
    familiar_afectado_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    familiar_catalogo_id smallint NOT NULL
);

--
-- Name: familiar_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.familiar_catalogo (
    familiar_catalogo_id smallint NOT NULL,
    nombre character varying(100) NOT NULL
);

--
-- Name: ficha_cambio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ficha_cambio (
    cambio_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    campo_modificado character varying(100),
    valor_anterior text,
    valor_nuevo text,
    justificacion character varying(500),
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    ip_origen character varying(45) NOT NULL
);

--
-- Name: COLUMN ficha_cambio.valor_anterior; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_cambio.valor_anterior IS 'Encriptado en reposo';

--
-- Name: COLUMN ficha_cambio.valor_nuevo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_cambio.valor_nuevo IS 'Encriptado en reposo';

--
-- Name: ficha_clinica; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ficha_clinica (
    ficha_id uuid DEFAULT gen_random_uuid() NOT NULL,
    paciente_id uuid NOT NULL,
    sesion_id uuid,
    origen_creacion character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    ultimo_autosave timestamp with time zone,
    medico_id uuid NOT NULL,
    fecha_consulta date NOT NULL,
    diagnosticos_ext_texto text,
    estado_ficha character varying(20) DEFAULT 'BORRADOR'::character varying NOT NULL,
    version_ficha smallint DEFAULT 1 NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone,
    creado_por uuid NOT NULL,
    modificado_por uuid,
    historia_clinica character varying(64) NOT NULL,
    id_tenant integer NOT NULL,
    ficha_raiz_id uuid NOT NULL,
    es_vigente boolean DEFAULT true NOT NULL,
    motivo_solicitud character varying(500),
    motivo_rechazo character varying(500),
    estado_revision character varying(16),
    fecha_resolucion timestamp with time zone,
    resuelta_por uuid,
    CONSTRAINT ck_ficha_estado_revision CHECK (((estado_revision IS NULL) OR ((estado_revision)::text = ANY ((ARRAY['PENDIENTE'::character varying, 'APROBADA'::character varying, 'RECHAZADA'::character varying])::text[]))))
);

--
-- Name: COLUMN ficha_clinica.ficha_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.ficha_id IS 'PK interna, nunca expuesta al sistema externo';

--
-- Name: COLUMN ficha_clinica.sesion_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.sesion_id IS 'FK a sesion_integracion. NULL si creación manual.';

--
-- Name: COLUMN ficha_clinica.origen_creacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.origen_creacion IS 'INTEGRACION | MANUAL';

--
-- Name: COLUMN ficha_clinica.ultimo_autosave; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.ultimo_autosave IS 'NULL si nunca se hizo autosave desde la creación';

--
-- Name: COLUMN ficha_clinica.medico_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.medico_id IS 'proveniente de sistema externo';

--
-- Name: COLUMN ficha_clinica.diagnosticos_ext_texto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.diagnosticos_ext_texto IS 'Texto libre proveniente del sistema externo — fuente para el modelo de data oscura';

--
-- Name: COLUMN ficha_clinica.estado_ficha; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.estado_ficha IS 'BORRADOR | COMPLETA | VALIDADA | ARCHIVADA';

--
-- Name: COLUMN ficha_clinica.version_ficha; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_clinica.version_ficha IS 'version de la ficha del sistema interno';

--
-- Name: ficha_provisional; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ficha_provisional (
    ficha_raiz_id uuid NOT NULL,
    id_tenant integer NOT NULL,
    historia_clinica_referida character varying(48) NOT NULL,
    historia_clinica_provisional character varying(64) NOT NULL,
    estado character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    creado_por uuid NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    intentos_consolidacion smallint DEFAULT 0 NOT NULL,
    ultimo_intento timestamp with time zone,
    ficha_consolidada_id uuid,
    historia_clinica_real character varying(64),
    resuelto_por uuid,
    fecha_resolucion timestamp with time zone,
    CONSTRAINT ck_ficha_provisional_adenda CHECK ((((estado)::text <> ALL ((ARRAY['EN_REVISION'::character varying, 'CONSOLIDADA'::character varying])::text[])) OR ((ficha_consolidada_id IS NOT NULL) AND (historia_clinica_real IS NOT NULL)))),
    CONSTRAINT ck_ficha_provisional_estado CHECK (((estado)::text = ANY ((ARRAY['PENDIENTE'::character varying, 'EN_REVISION'::character varying, 'CONSOLIDADA'::character varying, 'DESCARTADA'::character varying])::text[]))),
    CONSTRAINT ck_ficha_provisional_formato CHECK (((historia_clinica_provisional)::text = ((('TMP-'::text || id_tenant) || '-'::text) || (historia_clinica_referida)::text))),
    CONSTRAINT ck_ficha_provisional_intentos CHECK ((intentos_consolidacion >= 0)),
    CONSTRAINT ck_ficha_provisional_real CHECK (((historia_clinica_real IS NULL) OR (upper((historia_clinica_real)::text) !~~ 'TMP-%'::text))),
    CONSTRAINT ck_ficha_provisional_referida CHECK ((((historia_clinica_referida)::text ~ '^[A-Za-z0-9-]+$'::text) AND (upper((historia_clinica_referida)::text) !~~ 'TMP-%'::text))),
    CONSTRAINT ck_ficha_provisional_resolucion CHECK ((((estado)::text = ANY ((ARRAY['CONSOLIDADA'::character varying, 'DESCARTADA'::character varying])::text[])) = ((resuelto_por IS NOT NULL) AND (fecha_resolucion IS NOT NULL))))
);

--
-- Name: TABLE ficha_provisional; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ficha_provisional IS 'Ficha raiz registrada con historia clinica provisional (TMP-) porque la HC no existe en SADC. Una fila por ficha raiz.';

--
-- Name: COLUMN ficha_provisional.ficha_raiz_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.ficha_raiz_id IS 'Ficha raiz provisional. Cubre todas sus versiones y adendas.';

--
-- Name: COLUMN ficha_provisional.id_tenant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.id_tenant IS 'Institucion. Igual al id_tenant de la ficha raiz (lo valida el trigger).';

--
-- Name: COLUMN ficha_provisional.historia_clinica_referida; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.historia_clinica_referida IS 'HC que escribio el medico y no existio en SADC. El batch de consolidacion la vuelve a buscar.';

--
-- Name: COLUMN ficha_provisional.historia_clinica_provisional; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.historia_clinica_provisional IS 'TMP-<id_tenant>-<historia_clinica_referida>. Igual a ficha_clinica.historia_clinica de la raiz.';

--
-- Name: COLUMN ficha_provisional.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.estado IS 'PENDIENTE | EN_REVISION (adenda de consolidacion creada) | CONSOLIDADA | DESCARTADA';

--
-- Name: COLUMN ficha_provisional.creado_por; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.creado_por IS 'Medico que registro la ficha provisional';

--
-- Name: COLUMN ficha_provisional.intentos_consolidacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.intentos_consolidacion IS 'Veces que el batch consulto SADC sin encontrar la HC';

--
-- Name: COLUMN ficha_provisional.ultimo_intento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.ultimo_intento IS 'Ultima consulta del batch a SADC';

--
-- Name: COLUMN ficha_provisional.ficha_consolidada_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.ficha_consolidada_id IS 'Version (adenda) de la misma ficha raiz que lleva la HC real';

--
-- Name: COLUMN ficha_provisional.historia_clinica_real; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.historia_clinica_real IS 'HC encontrada en SADC al consolidar';

--
-- Name: COLUMN ficha_provisional.resuelto_por; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.resuelto_por IS 'Revisor que aprobo o descarto la consolidacion';

--
-- Name: COLUMN ficha_provisional.fecha_resolucion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ficha_provisional.fecha_resolucion IS 'Momento en que la consolidacion se aprobo o se descarto';

--
-- Name: institucion_tenant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institucion_tenant (
    id_tenant integer NOT NULL,
    nombre character varying(160) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: lateralidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lateralidad (
    lateralidad_id smallint NOT NULL,
    codigo character varying(10) NOT NULL,
    nombre character varying(20) NOT NULL,
    orden smallint NOT NULL,
    activo boolean DEFAULT true NOT NULL
);

--
-- Name: lateralidad_lateralidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lateralidad_lateralidad_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: lateralidad_lateralidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lateralidad_lateralidad_id_seq OWNED BY public.lateralidad.lateralidad_id;

--
-- Name: nonce_usado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nonce_usado (
    nonce character varying(100) NOT NULL,
    system_id character varying(50) NOT NULL,
    usado_en timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);

--
-- Name: COLUMN nonce_usado.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nonce_usado.expires_at IS 'Usado por job de limpieza: DELETE FROM nonce_usado WHERE expires_at < NOW()';

--
-- Name: observacion_ficha; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observacion_ficha (
    observacion_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    texto_enc bytea NOT NULL,
    texto_dek_enc bytea NOT NULL,
    agregada_en_revision boolean DEFAULT false NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    usuario_id uuid NOT NULL
);

--
-- Name: paciente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paciente (
    paciente_id uuid DEFAULT gen_random_uuid() NOT NULL,
    system_id character varying(50),
    paciente_ext_id character varying(64),
    nombre_enc bytea NOT NULL,
    nombre_dek_enc bytea NOT NULL,
    fecha_creacion_registro timestamp with time zone DEFAULT now() NOT NULL,
    ultima_sincronizacion timestamp with time zone
);

--
-- Name: COLUMN paciente.paciente_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.paciente_id IS 'id interno';

--
-- Name: COLUMN paciente.system_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.system_id IS 'Sistema externo propietario. NULL si es paciente creado manualmente';

--
-- Name: COLUMN paciente.paciente_ext_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.paciente_ext_id IS 'ID del paciente en el sistema externo';

--
-- Name: COLUMN paciente.nombre_enc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.nombre_enc IS 'Nombre completo encriptado';

--
-- Name: COLUMN paciente.nombre_dek_enc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.nombre_dek_enc IS 'DEK encriptada con clave maestra del proveedor KMS';

--
-- Name: COLUMN paciente.ultima_sincronizacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paciente.ultima_sincronizacion IS 'Última vez que se actualizó desde el sistema externo';

--
-- Name: paciente_nombre_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paciente_nombre_token (
    paciente_id uuid NOT NULL,
    token_hmac bytea NOT NULL
);

--
-- Name: parte_del_cuerpo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parte_del_cuerpo (
    parte_id smallint NOT NULL,
    region_id smallint NOT NULL,
    nombre character varying(50) NOT NULL,
    orden smallint DEFAULT 0 NOT NULL,
    requiere_lateralidad boolean DEFAULT true NOT NULL,
    permite_linea_media boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL
);

--
-- Name: parte_del_cuerpo_parte_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parte_del_cuerpo_parte_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: parte_del_cuerpo_parte_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parte_del_cuerpo_parte_id_seq OWNED BY public.parte_del_cuerpo.parte_id;

--
-- Name: referido_de; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referido_de (
    referido_de_id smallint NOT NULL,
    nombre character varying(100) NOT NULL
);

--
-- Name: region_anatomica; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region_anatomica (
    region_id smallint NOT NULL,
    nombre character varying(50) NOT NULL,
    orden smallint NOT NULL,
    activo boolean DEFAULT true NOT NULL
);

--
-- Name: region_anatomica_region_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.region_anatomica_region_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: region_anatomica_region_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.region_anatomica_region_id_seq OWNED BY public.region_anatomica.region_id;

--
-- Name: resultado_ia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resultado_ia (
    resultado_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    ejecutado_por uuid NOT NULL,
    modelo_utilizado character varying(100),
    version_modelo character varying(50) NOT NULL,
    resultado_raw jsonb NOT NULL,
    es_resultado_vigente boolean DEFAULT true NOT NULL,
    ejecutado_en timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: COLUMN resultado_ia.resultado_raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.resultado_ia.resultado_raw IS 'Response completo de la API. Inmutable.';

--
-- Name: COLUMN resultado_ia.es_resultado_vigente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.resultado_ia.es_resultado_vigente IS 'Partial unique index garantiza solo uno TRUE por ficha';

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(200) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: sesion_integracion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sesion_integracion (
    sesion_id uuid DEFAULT gen_random_uuid() NOT NULL,
    system_id character varying(50) NOT NULL,
    token_hash character(64) NOT NULL,
    patient_payload_enc jsonb NOT NULL,
    ficha_id uuid,
    estado character varying(20) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    activated_at timestamp with time zone,
    consumed_at timestamp with time zone,
    ip_origen_sadc character varying(45) NOT NULL,
    nonce character varying(100)
);

--
-- Name: COLUMN sesion_integracion.token_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sesion_integracion.token_hash IS 'SHA-256 del token entregado al sistema externo. El token real nunca se persiste.';

--
-- Name: COLUMN sesion_integracion.patient_payload_enc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sesion_integracion.patient_payload_enc IS 'Payload del sistema externo cifrado en reposo con AES-256-GCM.';

--
-- Name: COLUMN sesion_integracion.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sesion_integracion.estado IS 'PENDIENTE | ACTIVA | CONSUMIDA | EXPIRADA';

--
-- Name: COLUMN sesion_integracion.nonce; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sesion_integracion.nonce IS 'Para flujo intermedio anti-replay. NULL en flujo básico.';

--
-- Name: sexo_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sexo_catalogo (
    sexo_id smallint NOT NULL,
    codigo character varying(1) NOT NULL,
    nombre character varying(50) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    orden smallint NOT NULL
);

--
-- Name: signo_alerta_ficha; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signo_alerta_ficha (
    signo_id uuid DEFAULT gen_random_uuid() NOT NULL,
    ficha_id uuid NOT NULL,
    signo_texto_libre character varying(300) NOT NULL,
    parte_id smallint NOT NULL,
    imagen_bucket_ref character varying(500),
    imagen_hash_sha256 character(64),
    fecha_registro timestamp with time zone DEFAULT now() NOT NULL,
    registrado_por uuid NOT NULL,
    added_in_revision boolean DEFAULT false NOT NULL,
    replaces_signo_id uuid
);

--
-- Name: COLUMN signo_alerta_ficha.signo_texto_libre; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.signo_alerta_ficha.signo_texto_libre IS 'Texto libre ingresado por el médico';

--
-- Name: COLUMN signo_alerta_ficha.imagen_hash_sha256; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.signo_alerta_ficha.imagen_hash_sha256 IS 'Integridad del archivo en bucket';

--
-- Name: signo_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signo_catalogo (
    signo_catalogo_id integer NOT NULL,
    nombre_normalizado character varying(200) NOT NULL,
    categoria character varying(100),
    descripcion_medica text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: signo_catalogo_signo_catalogo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.signo_catalogo_signo_catalogo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: signo_catalogo_signo_catalogo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.signo_catalogo_signo_catalogo_id_seq OWNED BY public.signo_catalogo.signo_catalogo_id;

--
-- Name: sistema_externo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sistema_externo (
    system_id character varying(50) NOT NULL,
    nombre character varying(200) NOT NULL,
    api_key_hash character(64) NOT NULL,
    auth_method character varying(20) DEFAULT 'API_KEY'::character varying NOT NULL,
    oauth_client_id character varying(100),
    oauth_issuer character varying(300),
    oauth_audience character varying(100),
    activo_oauth boolean DEFAULT false NOT NULL,
    client_secret_hmac_hash character(64),
    webhook_callback_url character varying(500),
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp with time zone DEFAULT now() NOT NULL,
    fecha_ultimo_acceso timestamp with time zone
);

--
-- Name: COLUMN sistema_externo.api_key_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.api_key_hash IS 'SHA-256 del API Key. El key en texto plano nunca se almacena.';

--
-- Name: COLUMN sistema_externo.auth_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.auth_method IS 'API_KEY | OAUTH2 | HYBRID';

--
-- Name: COLUMN sistema_externo.oauth_client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.oauth_client_id IS 'Client ID registrado en el authorization server OAuth 2.0.';

--
-- Name: COLUMN sistema_externo.oauth_issuer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.oauth_issuer IS 'Issuer esperado del authorization server.';

--
-- Name: COLUMN sistema_externo.oauth_audience; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.oauth_audience IS 'Audience esperada para tokens destinados a CONGENIA.';

--
-- Name: COLUMN sistema_externo.activo_oauth; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.activo_oauth IS 'Permite autenticacion OAuth 2.0 para este sistema externo.';

--
-- Name: COLUMN sistema_externo.client_secret_hmac_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo.client_secret_hmac_hash IS 'Solo para flujo intermedio con firma HMAC. NULL en flujo básico.';

--
-- Name: sistema_externo_permiso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sistema_externo_permiso (
    system_id character varying(50) NOT NULL,
    permiso character varying(100) NOT NULL
);

--
-- Name: COLUMN sistema_externo_permiso.permiso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sistema_externo_permiso.permiso IS 'Scope/permiso interno autorizado para el sistema externo.';

--
-- Name: tipo_evento_catalogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipo_evento_catalogo (
    codigo character varying(50) NOT NULL,
    categoria character varying(20) NOT NULL,
    descripcion character varying(300) NOT NULL
);

--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    usuario_id uuid DEFAULT gen_random_uuid() NOT NULL,
    system_id character varying(50),
    usuario_ext_id character varying(50),
    nombre character varying(200) NOT NULL,
    email character varying(200),
    especialidad character varying(50) DEFAULT 'N/A'::character varying NOT NULL,
    rol character varying(20) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: COLUMN usuario.usuario_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.usuario_id IS 'PK interna';

--
-- Name: COLUMN usuario.system_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.system_id IS 'Sistema externo propietario. NULL si es usuario interno';

--
-- Name: COLUMN usuario.usuario_ext_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.usuario_ext_id IS 'ID del usuario en el sistema externo. NULL si es interno';

--
-- Name: COLUMN usuario.especialidad; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.especialidad IS 'Especialidad del medico. N/A si no aplica';

--
-- Name: COLUMN usuario.rol; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuario.rol IS 'MEDICO | GENETISTA | ADMINISTRADOR | SISTEMA_ANALISIS | READONLY';

--
-- Name: vw_congenia_fichas_anon; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_congenia_fichas_anon AS
 SELECT f.ficha_id,
    f.fecha_consulta,
    f.id_tenant,
    sc.codigo AS sexo,
    NULL::integer AS edad_anios,
    f.diagnosticos_ext_texto AS diagnostico,
    u.especialidad,
    f.fecha_creacion,
    f.origen_creacion,
    f.estado_ficha,
    f.version_ficha,
    rd.nombre AS referido_de,
    ap.nombre AS asistencia_parto,
    da.familiares_afectos,
    da.personas_hogar_menores,
    da.personas_hogar_adultos,
    da.comunidad_afectada,
    (EXISTS ( SELECT 1
           FROM public.ficha_provisional fp
          WHERE (fp.ficha_raiz_id = f.ficha_raiz_id))) AS es_provisional,
    ( SELECT (count(*))::integer AS count
           FROM public.familiar_afectado fa
          WHERE (fa.ficha_id = f.ficha_id)) AS numero_familiares_afectados,
    ( SELECT (count(*))::integer AS count
           FROM public.signo_alerta_ficha sa
          WHERE (sa.ficha_id = f.ficha_id)) AS numero_signos_alerta,
    ( SELECT (count(*))::integer AS count
           FROM public.examen_ficha ef
          WHERE (ef.ficha_id = f.ficha_id)) AS numero_examenes,
    ( SELECT (count(*))::integer AS count
           FROM public.observacion_ficha ob
          WHERE (ob.ficha_id = f.ficha_id)) AS numero_observaciones
   FROM (((((public.ficha_clinica f
     LEFT JOIN public.datos_adicionales_ficha da ON ((da.ficha_id = f.ficha_id)))
     LEFT JOIN public.sexo_catalogo sc ON ((sc.sexo_id = da.sexo_id)))
     LEFT JOIN public.usuario u ON ((u.usuario_id = f.medico_id)))
     LEFT JOIN public.referido_de rd ON ((rd.referido_de_id = da.referido_de_id)))
     LEFT JOIN public.asistencia_parto ap ON ((ap.asistencia_parto_id = da.asistencia_parto_id)))
  WHERE (f.es_vigente IS DISTINCT FROM false);

--
-- Name: examen_catalogo examen_catalogo_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_catalogo ALTER COLUMN examen_catalogo_id SET DEFAULT nextval('public.examen_catalogo_examen_catalogo_id_seq'::regclass);

--
-- Name: lateralidad lateralidad_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lateralidad ALTER COLUMN lateralidad_id SET DEFAULT nextval('public.lateralidad_lateralidad_id_seq'::regclass);

--
-- Name: parte_del_cuerpo parte_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parte_del_cuerpo ALTER COLUMN parte_id SET DEFAULT nextval('public.parte_del_cuerpo_parte_id_seq'::regclass);

--
-- Name: region_anatomica region_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_anatomica ALTER COLUMN region_id SET DEFAULT nextval('public.region_anatomica_region_id_seq'::regclass);

--
-- Name: signo_catalogo signo_catalogo_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_catalogo ALTER COLUMN signo_catalogo_id SET DEFAULT nextval('public.signo_catalogo_signo_catalogo_id_seq'::regclass);

--
-- Name: asistencia_parto asistencia_parto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asistencia_parto
    ADD CONSTRAINT asistencia_parto_pkey PRIMARY KEY (asistencia_parto_id);

--
-- Name: auditoria_evento auditoria_evento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_evento
    ADD CONSTRAINT auditoria_evento_pkey PRIMARY KEY (evento_id);

--
-- Name: consentimiento chk_evidencia_sin_png; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.consentimiento
    ADD CONSTRAINT chk_evidencia_sin_png CHECK ((NOT (firma_evidencia_tecnica ? 'firmaBase64'::text))) NOT VALID;

--
-- Name: cie10_catalogo cie10_catalogo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_catalogo
    ADD CONSTRAINT cie10_catalogo_codigo_key UNIQUE (codigo);

--
-- Name: cie10_catalogo cie10_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_catalogo
    ADD CONSTRAINT cie10_catalogo_pkey PRIMARY KEY (codigo_interno);

--
-- Name: cie10_clausula cie10_clausula_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_clausula
    ADD CONSTRAINT cie10_clausula_pkey PRIMARY KEY (version);

--
-- Name: cie10_decision_historial cie10_decision_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_decision_historial
    ADD CONSTRAINT cie10_decision_historial_pkey PRIMARY KEY (historial_id);

--
-- Name: cie10_decision cie10_decision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_decision
    ADD CONSTRAINT cie10_decision_pkey PRIMARY KEY (codigo_traductor);

--
-- Name: cie10_lote_confirmacion cie10_lote_confirmacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_lote_confirmacion
    ADD CONSTRAINT cie10_lote_confirmacion_pkey PRIMARY KEY (run_id);

--
-- Name: cie10_rag_catalogo cie10_rag_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_rag_catalogo
    ADD CONSTRAINT cie10_rag_catalogo_pkey PRIMARY KEY (rag_version, codigo);

--
-- Name: cie10_rag_version cie10_rag_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_rag_version
    ADD CONSTRAINT cie10_rag_version_pkey PRIMARY KEY (rag_version);

--
-- Name: cie10_revision_item cie10_revision_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_revision_item
    ADD CONSTRAINT cie10_revision_item_pkey PRIMARY KEY (run_id, codigo_traductor);

--
-- Name: cie10_run cie10_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_run
    ADD CONSTRAINT cie10_run_pkey PRIMARY KEY (run_id);

--
-- Name: cie10_sugerencia cie10_sugerencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_sugerencia
    ADD CONSTRAINT cie10_sugerencia_pkey PRIMARY KEY (codigo_traductor);

--
-- Name: consentimiento consentimiento_ficha_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento
    ADD CONSTRAINT consentimiento_ficha_id_key UNIQUE (ficha_id);

--
-- Name: consentimiento consentimiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento
    ADD CONSTRAINT consentimiento_pkey PRIMARY KEY (consentimiento_id);

--
-- Name: datos_adicionales_ficha datos_adicionales_ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_adicionales_ficha
    ADD CONSTRAINT datos_adicionales_ficha_pkey PRIMARY KEY (ficha_id);

--
-- Name: examen_catalogo examen_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_catalogo
    ADD CONSTRAINT examen_catalogo_pkey PRIMARY KEY (examen_catalogo_id);

--
-- Name: examen_ficha examen_ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_ficha
    ADD CONSTRAINT examen_ficha_pkey PRIMARY KEY (examen_ficha_id);

--
-- Name: familiar_afectado familiar_afectado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_afectado
    ADD CONSTRAINT familiar_afectado_pkey PRIMARY KEY (familiar_afectado_id);

--
-- Name: familiar_catalogo familiar_catalogo_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_catalogo
    ADD CONSTRAINT familiar_catalogo_nombre_key UNIQUE (nombre);

--
-- Name: familiar_catalogo familiar_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_catalogo
    ADD CONSTRAINT familiar_catalogo_pkey PRIMARY KEY (familiar_catalogo_id);

--
-- Name: ficha_cambio ficha_cambio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_cambio
    ADD CONSTRAINT ficha_cambio_pkey PRIMARY KEY (cambio_id);

--
-- Name: ficha_clinica ficha_clinica_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_pkey PRIMARY KEY (ficha_id);

--
-- Name: ficha_provisional ficha_provisional_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_pkey PRIMARY KEY (ficha_raiz_id);

--
-- Name: institucion_tenant institucion_tenant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institucion_tenant
    ADD CONSTRAINT institucion_tenant_pkey PRIMARY KEY (id_tenant);

--
-- Name: lateralidad lateralidad_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lateralidad
    ADD CONSTRAINT lateralidad_codigo_key UNIQUE (codigo);

--
-- Name: lateralidad lateralidad_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lateralidad
    ADD CONSTRAINT lateralidad_nombre_key UNIQUE (nombre);

--
-- Name: lateralidad lateralidad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lateralidad
    ADD CONSTRAINT lateralidad_pkey PRIMARY KEY (lateralidad_id);

--
-- Name: nonce_usado nonce_usado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nonce_usado
    ADD CONSTRAINT nonce_usado_pkey PRIMARY KEY (nonce);

--
-- Name: observacion_ficha observacion_ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observacion_ficha
    ADD CONSTRAINT observacion_ficha_pkey PRIMARY KEY (observacion_id);

--
-- Name: paciente_nombre_token paciente_nombre_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente_nombre_token
    ADD CONSTRAINT paciente_nombre_token_pkey PRIMARY KEY (paciente_id, token_hmac);

--
-- Name: paciente paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente
    ADD CONSTRAINT paciente_pkey PRIMARY KEY (paciente_id);

--
-- Name: parte_del_cuerpo parte_del_cuerpo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parte_del_cuerpo
    ADD CONSTRAINT parte_del_cuerpo_pkey PRIMARY KEY (parte_id);

--
-- Name: referido_de referido_de_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referido_de
    ADD CONSTRAINT referido_de_pkey PRIMARY KEY (referido_de_id);

--
-- Name: region_anatomica region_anatomica_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_anatomica
    ADD CONSTRAINT region_anatomica_nombre_key UNIQUE (nombre);

--
-- Name: region_anatomica region_anatomica_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region_anatomica
    ADD CONSTRAINT region_anatomica_pkey PRIMARY KEY (region_id);

--
-- Name: resultado_ia resultado_ia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resultado_ia
    ADD CONSTRAINT resultado_ia_pkey PRIMARY KEY (resultado_id);

--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);

--
-- Name: sesion_integracion sesion_integracion_nonce_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesion_integracion
    ADD CONSTRAINT sesion_integracion_nonce_key UNIQUE (nonce);

--
-- Name: sesion_integracion sesion_integracion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesion_integracion
    ADD CONSTRAINT sesion_integracion_pkey PRIMARY KEY (sesion_id);

--
-- Name: sesion_integracion sesion_integracion_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesion_integracion
    ADD CONSTRAINT sesion_integracion_token_hash_key UNIQUE (token_hash);

--
-- Name: sexo_catalogo sexo_catalogo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sexo_catalogo
    ADD CONSTRAINT sexo_catalogo_codigo_key UNIQUE (codigo);

--
-- Name: sexo_catalogo sexo_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sexo_catalogo
    ADD CONSTRAINT sexo_catalogo_pkey PRIMARY KEY (sexo_id);

--
-- Name: signo_alerta_ficha signo_alerta_ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_alerta_ficha
    ADD CONSTRAINT signo_alerta_ficha_pkey PRIMARY KEY (signo_id);

--
-- Name: signo_catalogo signo_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_catalogo
    ADD CONSTRAINT signo_catalogo_pkey PRIMARY KEY (signo_catalogo_id);

--
-- Name: sistema_externo_permiso sistema_externo_permiso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sistema_externo_permiso
    ADD CONSTRAINT sistema_externo_permiso_pkey PRIMARY KEY (system_id, permiso);

--
-- Name: sistema_externo sistema_externo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sistema_externo
    ADD CONSTRAINT sistema_externo_pkey PRIMARY KEY (system_id);

--
-- Name: tipo_evento_catalogo tipo_evento_catalogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipo_evento_catalogo
    ADD CONSTRAINT tipo_evento_catalogo_pkey PRIMARY KEY (codigo);

--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (usuario_id);

--
-- Name: brin_auditoria_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brin_auditoria_fecha ON public.auditoria_evento USING brin (fecha_hora);

--
-- Name: ix_auditoria_actor_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auditoria_actor_fecha ON public.auditoria_evento USING btree (actor_sub, fecha_hora);

--
-- Name: ix_auditoria_entidad_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auditoria_entidad_fecha ON public.auditoria_evento USING btree (entidad_tipo, entidad_id, fecha_hora);

--
-- Name: ix_auditoria_tipo_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auditoria_tipo_fecha ON public.auditoria_evento USING btree (tipo_evento, fecha_hora);

--
-- Name: ix_cie10_decision_historial_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_decision_historial_item ON public.cie10_decision_historial USING btree (codigo_traductor, fecha_evento DESC);

--
-- Name: ix_cie10_decision_revisor_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_decision_revisor_fecha ON public.cie10_decision USING btree (revisor_id, decidido_en DESC);

--
-- Name: ix_cie10_rag_catalogo_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_rag_catalogo_codigo ON public.cie10_rag_catalogo USING btree (codigo);

--
-- Name: ix_cie10_rag_catalogo_descripcion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_rag_catalogo_descripcion ON public.cie10_rag_catalogo USING btree (rag_version, descripcion_normalizada);

--
-- Name: ix_cie10_rag_catalogo_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_rag_catalogo_parent ON public.cie10_rag_catalogo USING btree (rag_version, parent_codigo);

--
-- Name: ix_cie10_revision_item_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_revision_item_run ON public.cie10_revision_item USING btree (run_id, codigo_traductor);

--
-- Name: ix_cie10_run_periodo_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_run_periodo_estado ON public.cie10_run USING btree (periodo DESC, estado, finished_at DESC);

--
-- Name: ix_cie10_sugerencia_orden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cie10_sugerencia_orden ON public.cie10_sugerencia USING btree (procesado_en, codigo_traductor);

--
-- Name: ix_ficha_adendas_tenant_estado_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_adendas_tenant_estado_fecha ON public.ficha_clinica USING btree (id_tenant, estado_revision, fecha_creacion DESC) WHERE (estado_revision IS NOT NULL);

--
-- Name: ix_ficha_cambio_ficha_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_cambio_ficha_fecha ON public.ficha_cambio USING btree (ficha_id, fecha_hora);

--
-- Name: ix_ficha_provisional_cola; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_provisional_cola ON public.ficha_provisional USING btree (ultimo_intento NULLS FIRST) WHERE ((estado)::text = 'PENDIENTE'::text);

--
-- Name: ix_ficha_provisional_tenant_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_provisional_tenant_estado ON public.ficha_provisional USING btree (id_tenant, estado, fecha_creacion DESC);

--
-- Name: ix_ficha_raiz_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_raiz_version ON public.ficha_clinica USING btree (ficha_raiz_id, version_ficha DESC);

--
-- Name: ix_ficha_tenant_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_tenant_fecha ON public.ficha_clinica USING btree (id_tenant, fecha_consulta DESC);

--
-- Name: ix_ficha_tenant_historia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ficha_tenant_historia ON public.ficha_clinica USING btree (id_tenant, historia_clinica);

--
-- Name: ix_observacion_ficha_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_observacion_ficha_fecha ON public.observacion_ficha USING btree (ficha_id, fecha_creacion, observacion_id);

--
-- Name: ix_paciente_nombre_token_hmac; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_paciente_nombre_token_hmac ON public.paciente_nombre_token USING btree (token_hmac);

--
-- Name: uq_paciente_system_ext; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_paciente_system_ext ON public.paciente USING btree (system_id, paciente_ext_id);

--
-- Name: uq_parte_region_nombre; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_parte_region_nombre ON public.parte_del_cuerpo USING btree (region_id, nombre);

--
-- Name: uq_usuario_system_ext; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_usuario_system_ext ON public.usuario USING btree (system_id, usuario_ext_id);

--
-- Name: ux_auditoria_secuencia; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_auditoria_secuencia ON public.auditoria_evento USING btree (secuencia);

--
-- Name: ux_cie10_clausula_activa; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_cie10_clausula_activa ON public.cie10_clausula USING btree (activa) WHERE (activa = true);

--
-- Name: ux_cie10_rag_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_cie10_rag_active ON public.cie10_rag_version USING btree (estado) WHERE ((estado)::text = 'ACTIVE'::text);

--
-- Name: ux_ficha_provisional_activa_hc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_ficha_provisional_activa_hc ON public.ficha_provisional USING btree (id_tenant, historia_clinica_referida) WHERE ((estado)::text = ANY ((ARRAY['PENDIENTE'::character varying, 'EN_REVISION'::character varying])::text[]));

--
-- Name: ux_ficha_raiz_vigente; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_ficha_raiz_vigente ON public.ficha_clinica USING btree (ficha_raiz_id) WHERE es_vigente;

--
-- Name: ux_ficha_vigente_por_hc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_ficha_vigente_por_hc ON public.ficha_clinica USING btree (id_tenant, historia_clinica) WHERE es_vigente;

--
-- Name: auditoria_evento trg_auditoria_evento_encadenar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_evento_encadenar BEFORE INSERT ON public.auditoria_evento FOR EACH ROW EXECUTE FUNCTION public.auditoria_evento_encadenar();

--
-- Name: auditoria_evento trg_auditoria_evento_inmutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_evento_inmutable BEFORE DELETE OR UPDATE ON public.auditoria_evento FOR EACH ROW EXECUTE FUNCTION public.bloquear_modificacion_auditoria();

--
-- Name: auditoria_evento trg_auditoria_evento_no_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_evento_no_truncate BEFORE TRUNCATE ON public.auditoria_evento FOR EACH STATEMENT EXECUTE FUNCTION public.bloquear_modificacion_auditoria();

--
-- Name: ficha_cambio trg_ficha_cambio_inmutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ficha_cambio_inmutable BEFORE DELETE OR UPDATE ON public.ficha_cambio FOR EACH ROW EXECUTE FUNCTION public.bloquear_modificacion_auditoria();

--
-- Name: ficha_cambio trg_ficha_cambio_no_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ficha_cambio_no_truncate BEFORE TRUNCATE ON public.ficha_cambio FOR EACH STATEMENT EXECUTE FUNCTION public.bloquear_modificacion_auditoria();

--
-- Name: ficha_provisional trg_ficha_provisional_no_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ficha_provisional_no_truncate BEFORE TRUNCATE ON public.ficha_provisional FOR EACH STATEMENT EXECUTE FUNCTION public.ficha_provisional_no_truncate();

--
-- Name: ficha_provisional trg_ficha_provisional_validar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ficha_provisional_validar BEFORE INSERT OR DELETE OR UPDATE ON public.ficha_provisional FOR EACH ROW EXECUTE FUNCTION public.ficha_provisional_validar();

--
-- Name: auditoria_evento auditoria_evento_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_evento
    ADD CONSTRAINT auditoria_evento_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: cie10_decision cie10_decision_codigo_interno_catalogo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_decision
    ADD CONSTRAINT cie10_decision_codigo_interno_catalogo_fkey FOREIGN KEY (codigo_interno_catalogo) REFERENCES public.cie10_catalogo(codigo_interno) DEFERRABLE;

--
-- Name: cie10_decision cie10_decision_codigo_traductor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_decision
    ADD CONSTRAINT cie10_decision_codigo_traductor_fkey FOREIGN KEY (codigo_traductor) REFERENCES public.cie10_sugerencia(codigo_traductor) DEFERRABLE;

--
-- Name: cie10_lote_confirmacion cie10_lote_confirmacion_clausula_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_lote_confirmacion
    ADD CONSTRAINT cie10_lote_confirmacion_clausula_version_fkey FOREIGN KEY (clausula_version) REFERENCES public.cie10_clausula(version);

--
-- Name: cie10_lote_confirmacion cie10_lote_confirmacion_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_lote_confirmacion
    ADD CONSTRAINT cie10_lote_confirmacion_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.cie10_run(run_id);

--
-- Name: cie10_rag_catalogo cie10_rag_catalogo_rag_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_rag_catalogo
    ADD CONSTRAINT cie10_rag_catalogo_rag_version_fkey FOREIGN KEY (rag_version) REFERENCES public.cie10_rag_version(rag_version) ON DELETE CASCADE;

--
-- Name: cie10_revision_item cie10_revision_item_codigo_traductor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_revision_item
    ADD CONSTRAINT cie10_revision_item_codigo_traductor_fkey FOREIGN KEY (codigo_traductor) REFERENCES public.cie10_sugerencia(codigo_traductor);

--
-- Name: cie10_revision_item cie10_revision_item_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_revision_item
    ADD CONSTRAINT cie10_revision_item_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.cie10_run(run_id);

--
-- Name: cie10_run cie10_run_rag_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_run
    ADD CONSTRAINT cie10_run_rag_version_fkey FOREIGN KEY (rag_version) REFERENCES public.cie10_rag_version(rag_version);

--
-- Name: cie10_sugerencia cie10_sugerencia_rag_version_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_sugerencia
    ADD CONSTRAINT cie10_sugerencia_rag_version_fkey FOREIGN KEY (rag_version) REFERENCES public.cie10_rag_version(rag_version);

--
-- Name: cie10_sugerencia cie10_sugerencia_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_sugerencia
    ADD CONSTRAINT cie10_sugerencia_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.cie10_run(run_id) DEFERRABLE;

--
-- Name: consentimiento consentimiento_anulado_por_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento
    ADD CONSTRAINT consentimiento_anulado_por_id_fkey FOREIGN KEY (anulado_por_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: consentimiento consentimiento_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento
    ADD CONSTRAINT consentimiento_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: consentimiento consentimiento_medico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento
    ADD CONSTRAINT consentimiento_medico_id_fkey FOREIGN KEY (medico_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: datos_adicionales_ficha datos_adicionales_ficha_asistencia_parto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_adicionales_ficha
    ADD CONSTRAINT datos_adicionales_ficha_asistencia_parto_id_fkey FOREIGN KEY (asistencia_parto_id) REFERENCES public.asistencia_parto(asistencia_parto_id) DEFERRABLE;

--
-- Name: datos_adicionales_ficha datos_adicionales_ficha_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_adicionales_ficha
    ADD CONSTRAINT datos_adicionales_ficha_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: datos_adicionales_ficha datos_adicionales_ficha_referido_de_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_adicionales_ficha
    ADD CONSTRAINT datos_adicionales_ficha_referido_de_id_fkey FOREIGN KEY (referido_de_id) REFERENCES public.referido_de(referido_de_id) DEFERRABLE;

--
-- Name: examen_ficha examen_ficha_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_ficha
    ADD CONSTRAINT examen_ficha_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: examen_ficha examen_ficha_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_ficha
    ADD CONSTRAINT examen_ficha_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: familiar_afectado familiar_afectado_familiar_catalogo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_afectado
    ADD CONSTRAINT familiar_afectado_familiar_catalogo_id_fkey FOREIGN KEY (familiar_catalogo_id) REFERENCES public.familiar_catalogo(familiar_catalogo_id) DEFERRABLE;

--
-- Name: familiar_afectado familiar_afectado_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.familiar_afectado
    ADD CONSTRAINT familiar_afectado_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: ficha_cambio ficha_cambio_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_cambio
    ADD CONSTRAINT ficha_cambio_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: ficha_cambio ficha_cambio_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_cambio
    ADD CONSTRAINT ficha_cambio_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: ficha_clinica ficha_clinica_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: ficha_clinica ficha_clinica_medico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_medico_id_fkey FOREIGN KEY (medico_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: ficha_clinica ficha_clinica_modificado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: ficha_clinica ficha_clinica_paciente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_paciente_id_fkey FOREIGN KEY (paciente_id) REFERENCES public.paciente(paciente_id) DEFERRABLE;

--
-- Name: ficha_clinica ficha_clinica_sesion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT ficha_clinica_sesion_id_fkey FOREIGN KEY (sesion_id) REFERENCES public.sesion_integracion(sesion_id) DEFERRABLE;

--
-- Name: ficha_provisional ficha_provisional_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: ficha_provisional ficha_provisional_ficha_consolidada_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_ficha_consolidada_id_fkey FOREIGN KEY (ficha_consolidada_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: ficha_provisional ficha_provisional_ficha_raiz_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_ficha_raiz_id_fkey FOREIGN KEY (ficha_raiz_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: ficha_provisional ficha_provisional_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.institucion_tenant(id_tenant) DEFERRABLE;

--
-- Name: ficha_provisional ficha_provisional_resuelto_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_provisional
    ADD CONSTRAINT ficha_provisional_resuelto_por_fkey FOREIGN KEY (resuelto_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: auditoria_evento fk_auditoria_tipo_evento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_evento
    ADD CONSTRAINT fk_auditoria_tipo_evento FOREIGN KEY (tipo_evento) REFERENCES public.tipo_evento_catalogo(codigo);

--
-- Name: datos_adicionales_ficha fk_datos_adicionales_sexo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datos_adicionales_ficha
    ADD CONSTRAINT fk_datos_adicionales_sexo FOREIGN KEY (sexo_id) REFERENCES public.sexo_catalogo(sexo_id) DEFERRABLE;

--
-- Name: examen_ficha fk_examen_replaces; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.examen_ficha
    ADD CONSTRAINT fk_examen_replaces FOREIGN KEY (replaces_examen_id) REFERENCES public.examen_ficha(examen_ficha_id) DEFERRABLE;

--
-- Name: ficha_clinica fk_ficha_institucion_tenant; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT fk_ficha_institucion_tenant FOREIGN KEY (id_tenant) REFERENCES public.institucion_tenant(id_tenant) DEFERRABLE;

--
-- Name: ficha_clinica fk_ficha_raiz; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT fk_ficha_raiz FOREIGN KEY (ficha_raiz_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: ficha_clinica fk_ficha_resuelta_por; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ficha_clinica
    ADD CONSTRAINT fk_ficha_resuelta_por FOREIGN KEY (resuelta_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: observacion_ficha fk_observacion_ficha; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observacion_ficha
    ADD CONSTRAINT fk_observacion_ficha FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: observacion_ficha fk_observacion_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observacion_ficha
    ADD CONSTRAINT fk_observacion_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: signo_alerta_ficha fk_signo_replaces; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_alerta_ficha
    ADD CONSTRAINT fk_signo_replaces FOREIGN KEY (replaces_signo_id) REFERENCES public.signo_alerta_ficha(signo_id) DEFERRABLE;

--
-- Name: nonce_usado nonce_usado_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nonce_usado
    ADD CONSTRAINT nonce_usado_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.sistema_externo(system_id) DEFERRABLE;

--
-- Name: paciente_nombre_token paciente_nombre_token_paciente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente_nombre_token
    ADD CONSTRAINT paciente_nombre_token_paciente_id_fkey FOREIGN KEY (paciente_id) REFERENCES public.paciente(paciente_id) ON DELETE CASCADE;

--
-- Name: paciente paciente_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente
    ADD CONSTRAINT paciente_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.sistema_externo(system_id) DEFERRABLE;

--
-- Name: parte_del_cuerpo parte_del_cuerpo_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parte_del_cuerpo
    ADD CONSTRAINT parte_del_cuerpo_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.region_anatomica(region_id) DEFERRABLE;

--
-- Name: resultado_ia resultado_ia_ejecutado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resultado_ia
    ADD CONSTRAINT resultado_ia_ejecutado_por_fkey FOREIGN KEY (ejecutado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: resultado_ia resultado_ia_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resultado_ia
    ADD CONSTRAINT resultado_ia_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: sesion_integracion sesion_integracion_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesion_integracion
    ADD CONSTRAINT sesion_integracion_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: sesion_integracion sesion_integracion_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sesion_integracion
    ADD CONSTRAINT sesion_integracion_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.sistema_externo(system_id) DEFERRABLE;

--
-- Name: signo_alerta_ficha signo_alerta_ficha_ficha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_alerta_ficha
    ADD CONSTRAINT signo_alerta_ficha_ficha_id_fkey FOREIGN KEY (ficha_id) REFERENCES public.ficha_clinica(ficha_id) DEFERRABLE;

--
-- Name: signo_alerta_ficha signo_alerta_ficha_parte_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_alerta_ficha
    ADD CONSTRAINT signo_alerta_ficha_parte_id_fkey FOREIGN KEY (parte_id) REFERENCES public.parte_del_cuerpo(parte_id) DEFERRABLE;

--
-- Name: signo_alerta_ficha signo_alerta_ficha_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signo_alerta_ficha
    ADD CONSTRAINT signo_alerta_ficha_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuario(usuario_id) DEFERRABLE;

--
-- Name: sistema_externo_permiso sistema_externo_permiso_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sistema_externo_permiso
    ADD CONSTRAINT sistema_externo_permiso_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.sistema_externo(system_id) DEFERRABLE;

--
-- Name: usuario usuario_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_system_id_fkey FOREIGN KEY (system_id) REFERENCES public.sistema_externo(system_id) DEFERRABLE;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO congenia_app;

--
-- Name: TABLE auditoria_evento; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.auditoria_evento TO congenia_app;

--
-- Name: TABLE asistencia_parto; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.asistencia_parto TO congenia_app;

--
-- Name: SEQUENCE auditoria_evento_secuencia_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.auditoria_evento_secuencia_seq TO congenia_app;

--
-- Name: TABLE cie10_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_catalogo TO congenia_app;

--
-- Name: TABLE cie10_clausula; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_clausula TO congenia_app;

--
-- Name: TABLE cie10_decision; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_decision TO congenia_app;

--
-- Name: TABLE cie10_decision_historial; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_decision_historial TO congenia_app;

--
-- Name: TABLE cie10_lote_confirmacion; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_lote_confirmacion TO congenia_app;

--
-- Name: TABLE cie10_rag_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_rag_catalogo TO congenia_app;

--
-- Name: TABLE cie10_rag_version; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_rag_version TO congenia_app;

--
-- Name: TABLE cie10_revision_item; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_revision_item TO congenia_app;

--
-- Name: TABLE cie10_run; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_run TO congenia_app;

--
-- Name: TABLE cie10_sugerencia; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.cie10_sugerencia TO congenia_app;

--
-- Name: TABLE consentimiento; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.consentimiento TO congenia_app;

--
-- Name: TABLE datos_adicionales_ficha; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.datos_adicionales_ficha TO congenia_app;

--
-- Name: TABLE examen_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.examen_catalogo TO congenia_app;

--
-- Name: SEQUENCE examen_catalogo_examen_catalogo_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.examen_catalogo_examen_catalogo_id_seq TO congenia_app;

--
-- Name: TABLE examen_ficha; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.examen_ficha TO congenia_app;

--
-- Name: TABLE familiar_afectado; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.familiar_afectado TO congenia_app;

--
-- Name: TABLE familiar_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.familiar_catalogo TO congenia_app;

--
-- Name: TABLE ficha_cambio; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.ficha_cambio TO congenia_app;

--
-- Name: TABLE ficha_clinica; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ficha_clinica TO congenia_app;

--
-- Name: TABLE ficha_provisional; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.estado; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(estado) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.intentos_consolidacion; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(intentos_consolidacion) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.ultimo_intento; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(ultimo_intento) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.ficha_consolidada_id; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(ficha_consolidada_id) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.historia_clinica_real; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(historia_clinica_real) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.resuelto_por; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(resuelto_por) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: COLUMN ficha_provisional.fecha_resolucion; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(fecha_resolucion) ON TABLE public.ficha_provisional TO congenia_app;

--
-- Name: TABLE institucion_tenant; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.institucion_tenant TO congenia_app;

--
-- Name: TABLE lateralidad; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.lateralidad TO congenia_app;

--
-- Name: SEQUENCE lateralidad_lateralidad_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.lateralidad_lateralidad_id_seq TO congenia_app;

--
-- Name: TABLE nonce_usado; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.nonce_usado TO congenia_app;

--
-- Name: TABLE observacion_ficha; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.observacion_ficha TO congenia_app;

--
-- Name: TABLE paciente; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.paciente TO congenia_app;

--
-- Name: TABLE paciente_nombre_token; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.paciente_nombre_token TO congenia_app;

--
-- Name: TABLE parte_del_cuerpo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.parte_del_cuerpo TO congenia_app;

--
-- Name: SEQUENCE parte_del_cuerpo_parte_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.parte_del_cuerpo_parte_id_seq TO congenia_app;

--
-- Name: TABLE referido_de; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.referido_de TO congenia_app;

--
-- Name: TABLE region_anatomica; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.region_anatomica TO congenia_app;

--
-- Name: SEQUENCE region_anatomica_region_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.region_anatomica_region_id_seq TO congenia_app;

--
-- Name: TABLE resultado_ia; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.resultado_ia TO congenia_app;

--
-- Name: TABLE schema_migrations; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.schema_migrations TO congenia_app;

--
-- Name: TABLE sesion_integracion; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sesion_integracion TO congenia_app;

--
-- Name: TABLE sexo_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sexo_catalogo TO congenia_app;

--
-- Name: TABLE signo_alerta_ficha; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.signo_alerta_ficha TO congenia_app;

--
-- Name: TABLE signo_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.signo_catalogo TO congenia_app;

--
-- Name: SEQUENCE signo_catalogo_signo_catalogo_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE public.signo_catalogo_signo_catalogo_id_seq TO congenia_app;

--
-- Name: TABLE sistema_externo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sistema_externo TO congenia_app;

--
-- Name: TABLE sistema_externo_permiso; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.sistema_externo_permiso TO congenia_app;

--
-- Name: TABLE tipo_evento_catalogo; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.tipo_evento_catalogo TO congenia_app;

--
-- Name: TABLE usuario; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.usuario TO congenia_app;

--
-- Name: TABLE vw_congenia_fichas_anon; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vw_congenia_fichas_anon TO congenia_app;

--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE congenia IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO congenia_app;

--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE congenia IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO congenia_app;

--
-- PostgreSQL database dump complete
--
