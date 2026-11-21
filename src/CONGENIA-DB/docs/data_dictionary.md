# Diccionario de datos - CONGENIA-DB

**Fuente:** `CONGENIA-M1-SERVER/db/init` en `de59065` (2026-10-18)  
**Ultima migracion:** `18_cie10_empty_suggestion_correction.sql`  
**Tablas:** 40

> Generado con `python scripts/sync_from_server.py`. La estructura se reescribe en cada corrida;
> las descripciones se conservan. Para cambiar una descripcion, edita `docs/descripciones.json`
> o agrega `COMMENT ON` en una migracion del server (tiene prioridad).

## Migraciones aplicadas

1. `01_schema.sql`
2. `02_seed.sql`
3. `03_ficha_contracts.sql`
4. `04_adenda_resolution.sql`
5. `05_tenant_integrity.sql`
6. `06_audit_trail.sql`
7. `07_patient_sex_observations.sql`
8. `08_cie10_dashboard.sql`
9. `09_reporting_agent.sql`
10. `10_ficha_provisional.sql`
11. `11_reporting_agent_audit.sql`
12. `12_firma_png_s3.sql`
13. `13_cie10_token_usage.sql`
14. `14_cie10_rag_autocoding.sql`
15. `15_reporting_agent_context.sql`
16. `16_cie10_batch_review.sql`
17. `17_cie10_hybrid_search.sql`
18. `18_cie10_empty_suggestion_correction.sql`

## Indice

**Usuarios e instituciones**

- [`usuario`](#usuario) - Usuarios del sistema con roles diferenciados
- [`institucion_tenant`](#institucion_tenant) - Instituciones (tenants)

**Integracion con sistemas externos**

- [`sistema_externo`](#sistema_externo) - Registro de sistemas externos autorizados para iniciar sesiones de integracion en CONGENIA
- [`sistema_externo_permiso`](#sistema_externo_permiso) - Permisos o scopes internos autorizados para cada sistema externo
- [`sesion_integracion`](#sesion_integracion) - Representa el handshake entre un sistema externo y CONGENIA
- [`nonce_usado`](#nonce_usado) - Registro de nonces consumidos para prevenir replay attacks en el flujo intermedio

**Pacientes**

- [`paciente`](#paciente) - Información de pacientes con encriptación de datos sensibles
- [`paciente_nombre_token`](#paciente_nombre_token) - Indice ciego para buscar pacientes por nombre sin descifrarlo: un HMAC por cada token normalizado del nombre

**Fichas clinicas**

- [`ficha_clinica`](#ficha_clinica) - Version de una ficha clinica
- [`datos_adicionales_ficha`](#datos_adicionales_ficha) - Información adicional y contextual de fichas clínicas (condiciones sociales y médicas)
- [`familiar_afectado`](#familiar_afectado) - Registro de familiares con historial de condiciones similares a la del paciente
- [`signo_alerta_ficha`](#signo_alerta_ficha) - Signos de alerta registrados en la ficha clínica mediante texto libre, con referencia a la parte del cuerpo afectada y evidencia fotográfica opcional
- [`examen_ficha`](#examen_ficha) - Exámenes realizados en la ficha, descritos mediante texto libre por el médico
- [`observacion_ficha`](#observacion_ficha) - Observaciones en texto libre de una ficha, cifradas en reposo con cifrado de sobre (DEK por registro)
- [`resultado_ia`](#resultado_ia) - Resultado de modelo IA ejecutados sobre las fichas clínicas
- [`ficha_provisional`](#ficha_provisional) - Ficha raiz registrada con historia clinica provisional (TMP-) porque la HC no existe en SADC

**Consentimiento informado**

- [`consentimiento`](#consentimiento) - Registro legal de consentimiento informado con firma electrónica y evidencia técnica

**Auditoria y control de cambios**

- [`auditoria_evento`](#auditoria_evento) - Bitacora de auditoria append-only con cadena de hashes
- [`tipo_evento_catalogo`](#tipo_evento_catalogo) - Catalogo cerrado de tipos de evento
- [`ficha_cambio`](#ficha_cambio) - Historial de cambios específicos en campos de fichas clínicas con encriptación

**Correccion CIE-10**

- [`cie10_run`](#cie10_run) - Una ejecucion del batch mensual CIE-10 (CONGENIA-CIE10)
- [`cie10_sugerencia`](#cie10_sugerencia) - Diagnostico pendiente de clasificar con las sugerencias de la IA
- [`cie10_decision`](#cie10_decision) - Decision vigente del revisor por diagnostico
- [`cie10_decision_historial`](#cie10_decision_historial) - Historial de decisiones CIE-10 (CREATED / UPDATED)
- [`cie10_catalogo`](#cie10_catalogo) - Catalogo CIE-10 institucional
- [`cie10_revision_item`](#cie10_revision_item) - Borrador de la revision de un lote: decision preliminar por registro antes de la confirmacion masiva
- [`cie10_lote_confirmacion`](#cie10_lote_confirmacion) - Aceptacion de la clausula y confirmacion masiva de un lote CIE-10
- [`cie10_clausula`](#cie10_clausula) - Clausulas que el revisor acepta antes de revisar un lote CIE-10 asistido por IA
- [`cie10_rag_version`](#cie10_rag_version) - Version del corpus RAG de CIE-10 (catalogo institucional + referencia externa) con sus embeddings
- [`cie10_rag_catalogo`](#cie10_rag_catalogo) - Codigos CIE-10 del corpus RAG de una version

**Catalogos**

- [`signo_catalogo`](#signo_catalogo) - Catálogo centralizado de signos de alerta disponibles en el sistema
- [`examen_catalogo`](#examen_catalogo) - Catálogo centralizado de exámenes disponibles
- [`region_anatomica`](#region_anatomica) - Agrupación anatómica de alto nivel
- [`parte_del_cuerpo`](#parte_del_cuerpo) - Partes anatómicas del cuerpo, organizadas por región
- [`lateralidad`](#lateralidad) - Catálogo de opciones de lateralidad aplicables al registro de signos de alerta
- [`referido_de`](#referido_de) - Catálogo de fuentes de referencia para pacientes
- [`asistencia_parto`](#asistencia_parto) - Catálogo de tipos de asistencia médica en el parto
- [`familiar_catalogo`](#familiar_catalogo) - Catálogo de tipos de relaciones familiares para registro de familiares afectados
- [`sexo_catalogo`](#sexo_catalogo) - Catalogo de sexo del paciente

**Control de migraciones**

- [`schema_migrations`](#schema_migrations) - Migraciones aplicadas por el servicio migrate (local) o make migrate (AWS)

---

## Usuarios e instituciones

### `usuario`

Usuarios del sistema con roles diferenciados.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `usuario_id` | uuid | NO | `gen_random_uuid()` | PK | PK interna |
| `system_id` | varchar(50) | SI |  | FK -> `sistema_externo.system_id` | Sistema externo propietario. NULL si es usuario interno |
| `usuario_ext_id` | varchar(50) | SI |  |  | ID del usuario en el sistema externo. NULL si es interno |
| `nombre` | varchar(200) | NO |  |  | Nombre completo |
| `email` | varchar(200) | SI |  |  | Correo electrónico |
| `especialidad` | varchar(50) | NO | `'N/A'` |  | Especialidad del medico. N/A si no aplica |
| `rol` | varchar(20) | NO |  |  | MEDICO \| GENETISTA \| ADMINISTRADOR \| SISTEMA_ANALISIS \| READONLY |
| `activo` | boolean | NO | `true` |  | Estado del usuario (default: true) |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de creación |

**Restricciones, indices y permisos:**

- Indice `uq_usuario_system_ext`: `UNIQUE (system_id, usuario_ext_id)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `institucion_tenant`

Instituciones (tenants). Keycloak decide a que tenants accede cada usuario; esta tabla guarda el nombre visible y da integridad referencial.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `id_tenant` | integer | NO |  | PK | ID de la institucion. Igual al atributo tenants del grupo en Keycloak |
| `nombre` | varchar(160) | NO |  |  | Nombre visible de la institucion |
| `activo` | boolean | NO | `true` |  | FALSE oculta la institucion en tenantOptions |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de alta |
| `fecha_modificacion` | timestamptz | NO | `now()` |  | Timestamp de la ultima modificacion |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Integracion con sistemas externos

### `sistema_externo`

Registro de sistemas externos autorizados para iniciar sesiones de integracion en CONGENIA. Esta tabla soporta la migracion controlada desde API Key legado hacia OAuth 2.0 Client Credentials. Durante la transicion, un sistema puede operar en modo `HYBRID`; a futuro el modo esperado para integraciones servidor-a-servidor es `OAUTH2`.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `system_id` | varchar(50) | NO |  | PK | Identificador legible del sistema externo. Ej: `SADC-COBAN-SANDBOX`. |
| `nombre` | varchar(200) | NO |  |  | Nombre descriptivo del sistema externo. |
| `api_key_hash` | char(64) | NO |  |  | SHA-256 del API Key. El key en texto plano nunca se almacena. |
| `auth_method` | varchar(20) | NO | `'API_KEY'` |  | API_KEY \| OAUTH2 \| HYBRID |
| `oauth_client_id` | varchar(100) | SI |  |  | Client ID registrado en el authorization server OAuth 2.0. |
| `oauth_issuer` | varchar(300) | SI |  |  | Issuer esperado del authorization server. |
| `oauth_audience` | varchar(100) | SI |  |  | Audience esperada para tokens destinados a CONGENIA. |
| `activo_oauth` | boolean | NO | `false` |  | Permite autenticacion OAuth 2.0 para este sistema externo. |
| `client_secret_hmac_hash` | char(64) | SI |  |  | Solo para flujo intermedio con firma HMAC. NULL en flujo básico. |
| `webhook_callback_url` | varchar(500) | SI |  |  | URL donde CONGENIA notifica cuando una ficha se completa. |
| `activo` | boolean | NO | `true` |  | Si `false`, el sistema no puede iniciar nuevas sesiones. Default: `true`. |
| `fecha_registro` | timestamptz | NO | `now()` |  | Timestamp de alta del sistema. Default: `now()`. |
| `fecha_ultimo_acceso` | timestamptz | SI |  |  | Se actualiza en cada llamada exitosa al endpoint de integracion. |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `sistema_externo_permiso`

Permisos o scopes internos autorizados para cada sistema externo. En el flujo OAuth 2.0, el access token demuestra autenticacion del cliente; esta tabla define que acciones puede ejecutar ese cliente dentro de CONGENIA. Por ejemplo, SADC puede tener permiso `congenia.sessions:init` para iniciar una sesion temporal de ficha, sin recibir permisos administrativos ni acceso a otros modulos.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `system_id` | varchar(50) | NO |  | PK, FK -> `sistema_externo.system_id` | Sistema externo autorizado. FK a `sistema_externo(system_id)`. |
| `permiso` | varchar(100) | NO |  | PK | Scope/permiso interno autorizado para el sistema externo. |

**Restricciones, indices y permisos:**

- PK compuesta: (system_id, permiso)
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `sesion_integracion`

Representa el handshake entre un sistema externo y CONGENIA. Ciclo de vida: `PENDIENTE -> ACTIVA -> CONSUMIDA` o `PENDIENTE -> EXPIRADA`. Con el flujo nuevo, la sesion inicial y el payload de ficha se guardan primero en Redis con llave `integration:{tokenHash}` y TTL corto. PostgreSQL queda como persistencia durable para cuando la ficha se guarde/finalice, para auditoria y para historico. Esta tabla documenta el modelo relacional de sesion de integracion y puede usarse para persistencia durable o trazabilidad adicional si se decide materializar la sesion fuera del cache.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `sesion_id` | uuid | NO | `gen_random_uuid()` | PK | ID interno de la sesion. Default: `gen_random_uuid()`. |
| `system_id` | varchar(50) | NO |  | FK -> `sistema_externo.system_id` | Sistema externo que inicio la sesion. FK a `sistema_externo(system_id)`. |
| `token_hash` | char(64) | NO |  | UNIQUE | SHA-256 del token entregado al sistema externo. El token real nunca se persiste. |
| `patient_payload_enc` | jsonb | NO |  |  | Payload del sistema externo cifrado en reposo con AES-256-GCM. |
| `ficha_id` | uuid | SI |  | FK -> `ficha_clinica.ficha_id` | NULL mientras la ficha solo existe como sesion temporal. Se asigna cuando se crea la ficha durable. FK a `ficha_clinica(ficha_id)`. |
| `estado` | varchar(20) | NO | `'PENDIENTE'` |  | PENDIENTE \| ACTIVA \| CONSUMIDA \| EXPIRADA |
| `expires_at` | timestamptz | NO |  |  | Timestamp de expiracion del token/sesion temporal. |
| `created_at` | timestamptz | NO | `now()` |  | Timestamp de creacion. Default: `now()`. |
| `activated_at` | timestamptz | SI |  |  | Timestamp de cuando el medico abrio el formulario por primera vez. |
| `consumed_at` | timestamptz | SI |  |  | Timestamp de cuando la ficha paso a estado completa o fue persistida definitivamente. |
| `ip_origen_sadc` | varchar(45) | NO |  |  | IPv4 o IPv6 del sistema externo que realizo la llamada. |
| `nonce` | varchar(100) | SI |  | UNIQUE | Para flujo intermedio anti-replay. NULL en flujo básico. |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `nonce_usado`

Registro de nonces consumidos para prevenir replay attacks en el flujo intermedio. Requiere job de limpieza periódico.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `nonce` | varchar(100) | NO |  | PK | Valor del nonce consumido |
| `system_id` | varchar(50) | NO |  | FK -> `sistema_externo.system_id` | Sistema externo que usó el nonce (FK → `sistema_externo`) |
| `usado_en` | timestamptz | NO | `now()` |  | Timestamp de uso (servidor, default: now()) |
| `expires_at` | timestamptz | NO |  |  | Usado por job de limpieza: DELETE FROM nonce_usado WHERE expires_at < NOW() |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Pacientes

### `paciente`

Información de pacientes con encriptación de datos sensibles.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `paciente_id` | uuid | NO | `gen_random_uuid()` | PK | id interno |
| `system_id` | varchar(50) | SI |  | FK -> `sistema_externo.system_id` | Sistema externo propietario. NULL si es paciente creado manualmente |
| `paciente_ext_id` | varchar(64) | SI |  |  | ID del paciente en el sistema externo |
| `nombre_enc` | bytea | NO |  |  | Nombre completo encriptado |
| `nombre_dek_enc` | bytea | NO |  |  | DEK encriptada con clave maestra del proveedor KMS |
| `fecha_creacion_registro` | timestamptz | NO | `now()` |  | Timestamp de creación (servidor) |
| `ultima_sincronizacion` | timestamptz | SI |  |  | Última vez que se actualizó desde el sistema externo |

**Restricciones, indices y permisos:**

- Indice `uq_paciente_system_ext`: `UNIQUE (system_id, paciente_ext_id)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `paciente_nombre_token`

Indice ciego para buscar pacientes por nombre sin descifrarlo: un HMAC por cada token normalizado del nombre.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `paciente_id` | uuid | NO |  | PK, FK -> `paciente.paciente_id` | Paciente al que pertenece el token |
| `token_hmac` | bytea | NO |  | PK | HMAC-SHA256 de un token del nombre. La llave vive fuera de la base |

**Restricciones, indices y permisos:**

- PK compuesta: (paciente_id, token_hmac)
- FK `paciente_nombre_token_paciente_id_fkey`: (paciente_id) -> `paciente`(paciente_id), ON DELETE CASCADE
- Indice `ix_paciente_nombre_token_hmac`: `(token_hmac)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Fichas clinicas

### `ficha_clinica`

Version de una ficha clinica. La ficha inicial y cada adenda son filas distintas que comparten ficha_raiz_id; solo una por raiz es vigente.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `ficha_id` | uuid | NO | `gen_random_uuid()` | PK | PK interna, nunca expuesta al sistema externo |
| `paciente_id` | uuid | NO |  | FK -> `paciente.paciente_id` | Paciente de la ficha |
| `sesion_id` | uuid | SI |  | FK -> `sesion_integracion.sesion_id` | FK a sesion_integracion. NULL si creación manual. |
| `origen_creacion` | varchar(20) | NO | `'MANUAL'` |  | INTEGRACION \| MANUAL |
| `ultimo_autosave` | timestamptz | SI |  |  | NULL si nunca se hizo autosave desde la creación |
| `medico_id` | uuid | NO |  | FK -> `usuario.usuario_id` | proveniente de sistema externo |
| `fecha_consulta` | date | NO |  |  | Fecha de la consulta |
| `diagnosticos_ext_texto` | text | SI |  |  | Texto libre proveniente del sistema externo — fuente para el modelo de data oscura |
| `estado_ficha` | varchar(20) | NO | `'BORRADOR'` |  | BORRADOR \| COMPLETA \| VALIDADA \| ARCHIVADA |
| `version_ficha` | smallint | NO | `1` |  | version de la ficha del sistema interno |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de creación |
| `fecha_modificacion` | timestamptz | SI |  |  | Timestamp última modificación |
| `creado_por` | uuid | NO |  | FK -> `usuario.usuario_id` | ID del usuario que creó (del sistema interno) |
| `modificado_por` | uuid | SI |  | FK -> `usuario.usuario_id` | ID del usuario que modificó |
| `historia_clinica` | varchar(64) | NO |  |  | Numero de historia clinica del paciente en la institucion. Se busca junto con id_tenant |
| `id_tenant` | integer | NO |  | FK -> `institucion_tenant.id_tenant` | Institucion duena de la ficha. El acceso a cada tenant lo otorga Keycloak |
| `ficha_raiz_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Primera version de la ficha. Todas las adendas apuntan a ella (en la original es su propio ficha_id) |
| `es_vigente` | boolean | NO | `true` |  | TRUE en la version que se muestra. Indice unico parcial: una vigente por ficha_raiz_id |
| `motivo_solicitud` | varchar(500) | SI |  |  | Motivo con el que el medico solicito la adenda |
| `motivo_rechazo` | varchar(500) | SI |  |  | Motivo del revisor al rechazar la adenda |
| `estado_revision` | varchar(16) | SI |  |  | NULL en la version original. PENDIENTE \| APROBADA \| RECHAZADA en las adendas |
| `fecha_resolucion` | timestamptz | SI |  |  | Cuando el revisor aprobo o rechazo la adenda |
| `resuelta_por` | uuid | SI |  | FK -> `usuario.usuario_id` | Revisor que resolvio la adenda |

**Restricciones, indices y permisos:**

- CHECK `ck_ficha_estado_revision`: `(estado_revision IS NULL OR (estado_revision = ANY ('PENDIENTE', 'APROBADA', 'RECHAZADA')))`
- Indice `ix_ficha_adendas_tenant_estado_fecha`: `(id_tenant, estado_revision, fecha_creacion DESC) WHERE estado_revision IS NOT NULL`
- Indice `ix_ficha_raiz_version`: `(ficha_raiz_id, version_ficha DESC)`
- Indice `ix_ficha_tenant_fecha`: `(id_tenant, fecha_consulta DESC)`
- Indice `ix_ficha_tenant_historia`: `(id_tenant, historia_clinica)`
- Indice `ux_ficha_raiz_vigente`: `UNIQUE (ficha_raiz_id) WHERE es_vigente`
- Indice `ux_ficha_vigente_por_hc`: `UNIQUE (id_tenant, historia_clinica) WHERE es_vigente`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `datos_adicionales_ficha`

Información adicional y contextual de fichas clínicas (condiciones sociales y médicas).

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `ficha_id` | uuid | NO |  | PK, FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica |
| `referido_de_id` | smallint | SI |  | FK -> `referido_de.referido_de_id` | Fuente de referencia (FK → `referido_de`) |
| `asistencia_parto_id` | smallint | SI |  | FK -> `asistencia_parto.asistencia_parto_id` | Tipo de asistencia en parto (FK → `asistencia_parto`) |
| `familiares_afectos` | boolean | NO | `false` |  | Indicador de familiares con condiciones similares |
| `personas_hogar_menores` | smallint | SI | `0` |  | Cantidad de menores en el hogar (default: 0) |
| `personas_hogar_adultos` | smallint | SI | `0` |  | Cantidad de adultos en el hogar (default: 0) |
| `comunidad_afectada` | varchar(20) | SI |  |  | SI \| NO \| DESCONOCIDO |
| `sexo_id` | smallint | SI |  | FK -> `sexo_catalogo.sexo_id` | Sexo del paciente |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `familiar_afectado`

Registro de familiares con historial de condiciones similares a la del paciente.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `familiar_afectado_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del registro |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica |
| `familiar_catalogo_id` | smallint | NO |  | FK -> `familiar_catalogo.familiar_catalogo_id` | Tipo de relación familiar (FK → `familiar_catalogo`) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `signo_alerta_ficha`

Signos de alerta registrados en la ficha clínica mediante texto libre, con referencia a la parte del cuerpo afectada y evidencia fotográfica opcional.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `signo_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del registro |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica |
| `signo_texto_libre` | varchar(300) | NO |  |  | Texto libre ingresado por el médico |
| `parte_id` | smallint | NO |  | FK -> `parte_del_cuerpo.parte_id` | Parte del cuerpo afectada (FK → `parte_del_cuerpo`) |
| `imagen_bucket_ref` | varchar(500) | SI |  |  | Referencia al archivo en bucket de almacenamiento |
| `imagen_hash_sha256` | char(64) | SI |  |  | Integridad del archivo en bucket |
| `fecha_registro` | timestamptz | NO | `now()` |  | Timestamp de registro (servidor) |
| `registrado_por` | uuid | NO |  | FK -> `usuario.usuario_id` | ID del usuario que registró (FK → `usuario`) |
| `added_in_revision` | boolean | NO | `false` |  | TRUE si el signo se agrego en una adenda |
| `replaces_signo_id` | uuid | SI |  | FK -> `signo_alerta_ficha.signo_id` | Signo de la version anterior que este reemplaza. NULL si es nuevo |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `examen_ficha`

Exámenes realizados en la ficha, descritos mediante texto libre por el médico.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `examen_ficha_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del registro |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica |
| `examen_texto_libre` | varchar(300) | NO |  |  | Texto libre ingresado por el médico |
| `imagen_bucket_ref` | varchar(500) | SI |  |  | Referencia al archivo en bucket |
| `imagen_hash_sha256` | char(64) | SI |  |  | Hash SHA-256 para integridad |
| `fecha_registro` | timestamptz | NO | `now()` |  | Timestamp de registro (servidor) |
| `registrado_por` | uuid | NO |  | FK -> `usuario.usuario_id` | ID del usuario (FK → `usuario`) |
| `added_in_revision` | boolean | NO | `false` |  | TRUE si el examen se agrego en una adenda |
| `replaces_examen_id` | uuid | SI |  | FK -> `examen_ficha.examen_ficha_id` | Examen de la version anterior que este reemplaza. NULL si es nuevo |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `observacion_ficha`

Observaciones en texto libre de una ficha, cifradas en reposo con cifrado de sobre (DEK por registro).

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `observacion_id` | uuid | NO | `gen_random_uuid()` | PK | ID de la observacion |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Version de la ficha en la que se registro |
| `texto_enc` | bytea | NO |  |  | Texto cifrado con la DEK |
| `texto_dek_enc` | bytea | NO |  |  | DEK cifrada con la clave maestra |
| `agregada_en_revision` | boolean | NO | `false` |  | TRUE si la observacion vino en una adenda |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de creacion |
| `usuario_id` | uuid | NO |  | FK -> `usuario.usuario_id` | Autor de la observacion |

**Restricciones, indices y permisos:**

- Indice `ix_observacion_ficha_fecha`: `(ficha_id, fecha_creacion, observacion_id)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `resultado_ia`

Resultado de modelo IA ejecutados sobre las fichas clínicas.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `resultado_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del resultado |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica |
| `ejecutado_por` | uuid | NO |  | FK -> `usuario.usuario_id` | ID del usuario/sistema que ejecutó el modelo (FK → `usuario`) |
| `modelo_utilizado` | varchar(100) | SI |  |  | Nombre del modelo IA utilizado |
| `version_modelo` | varchar(50) | NO |  |  | Versión específica del modelo |
| `resultado_raw` | jsonb | NO |  |  | Response completo de la API. Inmutable. |
| `es_resultado_vigente` | boolean | NO | `true` |  | Partial unique index garantiza solo uno TRUE por ficha |
| `ejecutado_en` | timestamptz | NO | `now()` |  | Timestamp de ejecución (servidor) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `ficha_provisional`

Ficha raiz registrada con historia clinica provisional (TMP-) porque la HC no existe en SADC. Una fila por ficha raiz.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `ficha_raiz_id` | uuid | NO |  | PK, FK -> `ficha_clinica.ficha_id` | Ficha raiz provisional. Cubre todas sus versiones y adendas. |
| `id_tenant` | integer | NO |  | FK -> `institucion_tenant.id_tenant` | Institucion. Igual al id_tenant de la ficha raiz (lo valida el trigger). |
| `historia_clinica_referida` | varchar(48) | NO |  |  | HC que escribio el medico y no existio en SADC. El batch de consolidacion la vuelve a buscar. |
| `historia_clinica_provisional` | varchar(64) | NO |  |  | TMP-<id_tenant>-<historia_clinica_referida>. Igual a ficha_clinica.historia_clinica de la raiz. |
| `estado` | varchar(20) | NO | `'PENDIENTE'` |  | PENDIENTE \| EN_REVISION (adenda de consolidacion creada) \| CONSOLIDADA \| DESCARTADA |
| `creado_por` | uuid | NO |  | FK -> `usuario.usuario_id` | Medico que registro la ficha provisional |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Momento en que se registro la ficha provisional |
| `intentos_consolidacion` | smallint | NO | `0` |  | Veces que el batch consulto SADC sin encontrar la HC |
| `ultimo_intento` | timestamptz | SI |  |  | Ultima consulta del batch a SADC |
| `ficha_consolidada_id` | uuid | SI |  | FK -> `ficha_clinica.ficha_id` | Version (adenda) de la misma ficha raiz que lleva la HC real |
| `historia_clinica_real` | varchar(64) | SI |  |  | HC encontrada en SADC al consolidar |
| `resuelto_por` | uuid | SI |  | FK -> `usuario.usuario_id` | Revisor que aprobo o descarto la consolidacion |
| `fecha_resolucion` | timestamptz | SI |  |  | Momento en que la consolidacion se aprobo o se descarto |

**Restricciones, indices y permisos:**

- CHECK `ck_ficha_provisional_adenda`: `((estado <> ALL ('EN_REVISION', 'CONSOLIDADA')) OR ficha_consolidada_id IS NOT NULL AND historia_clinica_real IS NOT NULL)`
- CHECK `ck_ficha_provisional_estado`: `(estado = ANY ('PENDIENTE', 'EN_REVISION', 'CONSOLIDADA', 'DESCARTADA'))`
- CHECK `ck_ficha_provisional_formato`: `(historia_clinica_provisional = ((('TMP-' \|\| id_tenant) \|\| '-') \|\| historia_clinica_referida))`
- CHECK `ck_ficha_provisional_intentos`: `(intentos_consolidacion >= 0)`
- CHECK `ck_ficha_provisional_real`: `(historia_clinica_real IS NULL OR upper(historia_clinica_real) !~~ 'TMP-%')`
- CHECK `ck_ficha_provisional_referida`: `(historia_clinica_referida ~ '^[A-Za-z0-9-]+$' AND upper(historia_clinica_referida) !~~ 'TMP-%')`
- CHECK `ck_ficha_provisional_resolucion`: `((estado = ANY ('CONSOLIDADA', 'DESCARTADA')) = (resuelto_por IS NOT NULL AND fecha_resolucion IS NOT NULL))`
- Indice `ix_ficha_provisional_cola`: `(ultimo_intento) WHERE estado::text = 'PENDIENTE'::text`
- Indice `ix_ficha_provisional_tenant_estado`: `(id_tenant, estado, fecha_creacion DESC)`
- Indice `ux_ficha_provisional_activa_hc`: `UNIQUE (id_tenant, historia_clinica_referida) WHERE estado::text = ANY (ARRAY['PENDIENTE'::character varying, 'EN_REVISION'::character varying]::text[])`
- Trigger `trg_ficha_provisional_no_truncate` -> `ficha_provisional_no_truncate()`
- Trigger `trg_ficha_provisional_validar` -> `ficha_provisional_validar()`
- Permisos: `congenia_app`: INSERT, SELECT

---

## Consentimiento informado

### `consentimiento`

Registro legal de consentimiento informado con firma electrónica y evidencia técnica.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `consentimiento_id` | uuid | NO | `gen_random_uuid()` | PK | ID único |
| `ficha_id` | uuid | NO |  | UNIQUE, FK -> `ficha_clinica.ficha_id` | Referencia única a ficha (1 consentimiento por ficha) |
| `medico_id` | uuid | NO |  | FK -> `usuario.usuario_id` | Médico responsable (FK → `usuario`) |
| `tipo_firmante` | varchar(50) | NO |  |  | PADRE \| MADRE \| TUTOR \| REPRESENTANTE_LEGAL |
| `nombre_firmante` | varchar(200) | SI |  |  | Nombre del firmante |
| `idioma_consentimiento` | varchar(20) | NO |  |  | ESPANOL \| QEQCHI \| IXIL |
| `aceptacion_terminos` | boolean | NO |  |  | Siempre TRUE para persistir. Constraint a nivel de app y BD. |
| `aceptacion_contacto` | boolean | SI |  |  | Acepta ser contactado para seguimiento. Opcional |
| `fecha_hora_aceptacion` | timestamptz | NO |  |  | NTP del servidor. Nunca hora del cliente. |
| `firma_evidencia_tecnica` | jsonb | NO |  |  | Metadatos de la captura (timestamp, userAgent, canvasHash, version legal) y declaraciones aceptadas. Nunca la imagen ni el trazo de la firma. |
| `firma_png_ref` | varchar(500) | SI |  |  | Clave S3 del PNG de la firma, en el bucket de documentos. |
| `pdf_ref` | varchar(500) | SI |  |  | Referencia a PDF del consentimiento en bucket |
| `pdf_hash_sha256` | char(64) | NO |  |  | Hash SHA-256 del PDF |
| `firma_png_hash_sha256` | char(64) | NO |  |  | SHA-256 de los bytes del PNG de la firma. El worker lo verifica antes de generar el PDF. |
| `json_hash_sha256` | char(64) | NO |  |  | SHA-256 de firma_evidencia_tecnica serializada como JSON canonico (claves ordenadas, sin espacios). |
| `ip_dispositivo` | varchar(45) | NO |  |  | IPv4 o IPv6 |
| `session_id` | varchar(100) | SI |  |  | ID de sesión de la firma |
| `estado_consentimiento` | varchar(20) | NO | `'VIGENTE'` |  | VIGENTE \| ANULADO |
| `anulado_por_id` | uuid | SI |  | FK -> `usuario.usuario_id` | ID del usuario que anuló (FK → `usuario`) |
| `fecha_anulacion` | timestamptz | SI |  |  | Timestamp de anulación |

**Restricciones, indices y permisos:**

- CHECK `chk_evidencia_sin_png`: `(NOT firma_evidencia_tecnica ? 'firmaBase64') NOT VALID`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Auditoria y control de cambios

### `auditoria_evento`

Bitacora de auditoria append-only con cadena de hashes. Un trigger asigna secuencia y hashes; otros bloquean UPDATE, DELETE y TRUNCATE. Verificacion: SELECT * FROM verificar_cadena_auditoria().

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `evento_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del evento |
| `usuario_id` | uuid | SI |  | FK -> `usuario.usuario_id` | NULL si el evento es previo a autenticación |
| `tipo_evento` | varchar(50) | NO |  | FK -> `tipo_evento_catalogo.codigo` | FK a tipo_evento_catalogo |
| `entidad_tipo` | varchar(50) | SI |  |  | Ficha \| Consentimiento \| Signo \| Examen \| Sesion |
| `entidad_id` | uuid | SI |  |  | ID del objeto afectado |
| `ip_origen` | varchar(45) | NO |  |  | IPv4 o IPv6 de origen |
| `user_agent` | varchar(500) | SI |  |  | User-Agent del navegador/cliente |
| `session_id` | varchar(100) | SI |  |  | ID de sesión |
| `fecha_hora` | timestamptz | NO | `now()` |  | Timestamp NTP del servidor |
| `resultado` | varchar(20) | NO |  |  | EXITOSO \| FALLIDO \| DENEGADO |
| `detalle_json` | jsonb | SI |  |  | Contexto adicional estructurado por tipo de evento |
| `hash_entrada_anterior` | char(64) | SI |  |  | hash_entrada_actual de la fila con la secuencia previa. Genesis: 64 ceros |
| `hash_entrada_actual` | char(64) | NO |  |  | auditoria_evento_hash(fila): SHA-256 de los campos canonicos + hash_entrada_anterior |
| `secuencia` | bigint | NO |  |  | Orden total de la cadena. Lo asigna el trigger, no la aplicacion |
| `actor_sub` | varchar(100) | SI |  |  | Subject de Keycloak, client:<system_id> o system:<servicio> |
| `actor_username` | varchar(200) | SI |  |  | Username de Keycloak, o ID del medico externo en sesiones de integracion |
| `actor_roles` | text[] | SI |  |  | Roles del token al momento del evento |
| `id_tenant` | integer | SI |  |  | Institucion afectada cuando el evento toca un paciente |
| `http_method` | varchar(10) | SI |  |  | Metodo HTTP de la peticion |
| `ruta` | varchar(300) | SI |  |  | Plantilla de la ruta (ej: /api/v1/fichas/:id), nunca la URL con identificadores |
| `status_code` | smallint | SI |  |  | Codigo HTTP de la respuesta |
| `request_id` | varchar(100) | SI |  |  | X-Request-Id para correlacionar con los logs de la aplicacion |

**Restricciones, indices y permisos:**

- Indice `brin_auditoria_fecha`: `BRIN (fecha_hora)`
- Indice `ix_auditoria_actor_fecha`: `(actor_sub, fecha_hora)`
- Indice `ix_auditoria_entidad_fecha`: `(entidad_tipo, entidad_id, fecha_hora)`
- Indice `ix_auditoria_tipo_fecha`: `(tipo_evento, fecha_hora)`
- Indice `ux_auditoria_secuencia`: `UNIQUE (secuencia)`
- Trigger `trg_auditoria_evento_encadenar` -> `auditoria_evento_encadenar()`
- Trigger `trg_auditoria_evento_inmutable` -> `bloquear_modificacion_auditoria()`
- Trigger `trg_auditoria_evento_no_truncate` -> `bloquear_modificacion_auditoria()`
- Permisos: `congenia_app`: INSERT, SELECT

### `tipo_evento_catalogo`

Catalogo cerrado de tipos de evento. auditoria_evento.tipo_evento tiene FK aqui: un tipo nuevo se registra en la misma migracion que lo introduce.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `codigo` | varchar(50) | NO |  | PK | Codigo del evento (ej: FICHA_LEIDA) |
| `categoria` | varchar(20) | NO |  |  | ACCESO \| CONSULTA \| MODIFICACION \| VALIDACION \| INTEGRACION \| ARCHIVO \| CATALOGO |
| `descripcion` | varchar(300) | NO |  |  | Que representa el evento |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: SELECT

### `ficha_cambio`

Historial de cambios específicos en campos de fichas clínicas con encriptación.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `cambio_id` | uuid | NO | `gen_random_uuid()` | PK | ID único del cambio |
| `ficha_id` | uuid | NO |  | FK -> `ficha_clinica.ficha_id` | Referencia a ficha clínica (FK → `ficha_clinica`) |
| `usuario_id` | uuid | NO |  | FK -> `usuario.usuario_id` | Usuario que realizó el cambio (FK → `usuario`) |
| `campo_modificado` | varchar(100) | SI |  |  | Nombre del campo que cambió |
| `valor_anterior` | text | SI |  |  | Encriptado en reposo |
| `valor_nuevo` | text | SI |  |  | Encriptado en reposo |
| `justificacion` | varchar(500) | SI |  |  | Razón del cambio |
| `fecha_hora` | timestamptz | NO | `now()` |  | Timestamp del cambio (servidor) |
| `ip_origen` | varchar(45) | NO |  |  | IPv4 o IPv6 de origen |

**Restricciones, indices y permisos:**

- Indice `ix_ficha_cambio_ficha_fecha`: `(ficha_id, fecha_hora)`
- Trigger `trg_ficha_cambio_inmutable` -> `bloquear_modificacion_auditoria()`
- Trigger `trg_ficha_cambio_no_truncate` -> `bloquear_modificacion_auditoria()`
- Permisos: `congenia_app`: INSERT, SELECT

---

## Correccion CIE-10

### `cie10_run`

Una ejecucion del batch mensual CIE-10 (CONGENIA-CIE10).

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `run_id` | uuid | NO | `gen_random_uuid()` | PK | ID de la corrida |
| `estado` | varchar(20) | NO | `'RUNNING'` |  | RUNNING \| COMPLETED \| FAILED |
| `source_catalog_uri` | text | NO |  |  | Ruta local o s3:// del CSV del catalogo usado |
| `source_translator_uri` | text | NO |  |  | Ruta local o s3:// del CSV de diagnosticos (traductor) usado |
| `model` | varchar(100) | NO |  |  | Modelo de OpenAI usado |
| `prompt_version` | varchar(50) | NO |  |  | Version del prompt del sistema |
| `max_records` | integer | SI |  |  | Limite de registros procesados. NULL = sin limite |
| `processed_count` | integer | NO | `0` |  | Registros procesados |
| `suggestion_count` | integer | NO | `0` |  | Registros con sugerencias validas |
| `error_count` | integer | NO | `0` |  | Registros que fallaron |
| `started_at` | timestamptz | NO | `now()` |  | Inicio de la corrida |
| `finished_at` | timestamptz | SI |  |  | Fin de la corrida |
| `metadata_json` | jsonb | NO | `'{}'` |  | Metadatos adicionales de la corrida |
| `input_tokens` | bigint | NO | `0` |  | Tokens de entrada enviados al modelo en la corrida |
| `cached_input_tokens` | bigint | NO | `0` |  | Tokens de entrada servidos desde cache en la corrida |
| `output_tokens` | bigint | NO | `0` |  | Tokens de salida del modelo en la corrida |
| `reasoning_tokens` | bigint | NO | `0` |  | Tokens de razonamiento del modelo en la corrida |
| `total_tokens` | bigint | NO | `0` |  | Total de tokens consumidos en la corrida |
| `api_call_count` | integer | NO | `0` |  | Llamadas a la API del modelo en la corrida |
| `rag_version` | varchar(80) | SI |  | FK -> `cie10_rag_version.rag_version` | Version del corpus RAG usada en la corrida |
| `periodo` | char(7) | SI |  |  | Mes revisado (YYYY-MM). Agrupa el lote mensual que confirma el revisor |

**Restricciones, indices y permisos:**

- CHECK `cie10_run_estado_check`: `(estado = ANY ('RUNNING', 'COMPLETED', 'FAILED'))`
- CHECK `cie10_run_periodo_chk`: `(periodo IS NULL OR periodo ~ '^\d{4}-(0[1-9]\|1[0-2])$')`
- Indice `ix_cie10_run_periodo_estado`: `(periodo DESC, estado, finished_at DESC)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_sugerencia`

Diagnostico pendiente de clasificar con las sugerencias de la IA. Una fila por registro del traductor; es la cola del dashboard.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `codigo_traductor` | varchar | NO |  | PK | ID del registro en el CSV del traductor |
| `run_id` | uuid | NO |  | FK -> `cie10_run.run_id` | Corrida que genero la sugerencia |
| `diagnostico` | text | NO |  |  | Texto libre del diagnostico de emergencia. Puede contener datos clinicos sensibles y se envia a OpenAI |
| `cie10_original` | varchar | SI |  |  | Codigo interno asignado originalmente en el traductor |
| `ai_status` | varchar(40) | NO | `'suggestions'` |  | suggestions \| insufficient_information \| error |
| `sugerencias` | jsonb | NO | `'[]'` |  | Arreglo JSON ordenado de codigos sugeridos, validados contra cie10_catalogo |
| `razonamiento_clinico` | text | SI |  |  | Explicacion del modelo |
| `error` | text | SI |  |  | Mensaje de error cuando ai_status = error |
| `modelo` | varchar(100) | NO |  |  | Modelo que genero la sugerencia |
| `procesado_en` | timestamptz | NO | `now()` |  | Cuando se proceso |
| `input_tokens` | bigint | NO | `0` |  | Tokens de entrada enviados al modelo para este registro |
| `cached_input_tokens` | bigint | NO | `0` |  | Tokens de entrada servidos desde cache para este registro |
| `output_tokens` | bigint | NO | `0` |  | Tokens de salida del modelo para este registro |
| `reasoning_tokens` | bigint | NO | `0` |  | Tokens de razonamiento del modelo para este registro |
| `total_tokens` | bigint | NO | `0` |  | Total de tokens consumidos para este registro |
| `api_call_count` | integer | NO | `0` |  | Llamadas a la API del modelo para este registro |
| `rag_version` | varchar(80) | SI |  | FK -> `cie10_rag_version.rag_version` | Version del corpus RAG usada para sugerir |
| `input_sha256` | char(64) | SI |  |  | SHA-256 de la entrada enviada al modelo |

**Restricciones, indices y permisos:**

- CHECK `cie10_sugerencia_ai_status_check`: `(ai_status = ANY ('suggestions', 'insufficient_information', 'error'))`
- Indice `ix_cie10_sugerencia_orden`: `(procesado_en, codigo_traductor)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_decision`

Decision vigente del revisor por diagnostico. Una correccion la actualiza y deja rastro en cie10_decision_historial y en auditoria_evento.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `codigo_traductor` | varchar | NO |  | PK, FK -> `cie10_sugerencia.codigo_traductor` | Diagnostico decidido |
| `decision` | varchar(10) | NO |  |  | ACEPTADA (eligio una sugerencia) \| RECHAZADA (ingreso otro codigo) |
| `codigo_final` | varchar(8) | NO |  |  | Codigo CIE-10 elegido |
| `codigo_interno_catalogo` | varchar | SI |  | FK -> `cie10_catalogo.codigo_interno` | Codigo interno del catalogo correspondiente a codigo_final |
| `comentario` | varchar(300) | SI |  |  | Comentario del revisor (motivo del rechazo) |
| `posicion` | smallint | SI |  |  | Posicion (desde 1) de la sugerencia aceptada. NULL si se rechazo |
| `sugerencias_mostradas` | smallint | NO |  |  | Cuantas sugerencias vio el revisor |
| `revisor_id` | varchar | NO |  |  | Subject de Keycloak del revisor |
| `revisor_nombre` | varchar(200) | NO |  |  | Nombre del revisor al momento de decidir |
| `decidido_en` | timestamptz | NO | `now()` |  | Timestamp de la decision |

**Restricciones, indices y permisos:**

- CHECK `cie10_decision_decision_check`: `(decision = ANY ('ACEPTADA', 'RECHAZADA'))`
- Indice `ix_cie10_decision_revisor_fecha`: `(revisor_id, decidido_en DESC)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_decision_historial`

Historial de decisiones CIE-10 (CREATED / UPDATED). Pensado como append-only, pero hoy congenia_app tiene UPDATE y no tiene trigger de inmutabilidad.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `historial_id` | uuid | NO | `gen_random_uuid()` | PK | ID del registro de historial |
| `codigo_traductor` | varchar | NO |  |  | Diagnostico afectado (sin FK) |
| `accion` | varchar(20) | NO |  |  | CREATED \| UPDATED |
| `decision_anterior` | jsonb | SI |  |  | Decision previa. NULL en CREATED |
| `decision_nueva` | jsonb | NO |  |  | Decision resultante |
| `revisor_id` | varchar | NO |  |  | Subject de Keycloak de quien hizo el cambio |
| `fecha_evento` | timestamptz | NO | `now()` |  | Timestamp del cambio |

**Restricciones, indices y permisos:**

- CHECK `cie10_decision_historial_accion_check`: `(accion = ANY ('CREATED', 'UPDATED'))`
- Indice `ix_cie10_decision_historial_item`: `(codigo_traductor, fecha_evento DESC)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_catalogo`

Catalogo CIE-10 institucional. El batch lo reemplaza en cada corrida: marca todo inactivo y reactiva lo que viene en el CSV.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `codigo_interno` | varchar | NO |  | PK | ID interno del catalogo del hospital (columna Codigo del CSV) |
| `codigo` | varchar(8) | NO |  | UNIQUE | Codigo CIE-10 oficial (ej: A00.0) |
| `nombre` | text | NO |  |  | Descripcion del diagnostico |
| `activo` | boolean | NO | `true` |  | FALSE si no vino en el ultimo CSV importado |
| `importado_en` | timestamptz | NO | `now()` |  | Ultima importacion |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_revision_item`

Borrador de la revision de un lote: decision preliminar por registro antes de la confirmacion masiva.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `run_id` | uuid | NO |  | PK, FK -> `cie10_run.run_id` | Corrida (lote) revisada |
| `codigo_traductor` | varchar | NO |  | PK, FK -> `cie10_sugerencia.codigo_traductor` | Registro del traductor |
| `codigo_final` | varchar(8) | NO |  |  | Codigo CIE-10 elegido en el borrador |
| `comentario` | varchar(300) | SI |  |  | Comentario del revisor (hasta 300 caracteres) |
| `corregido` | boolean | NO | `false` |  | TRUE si el revisor ingreso otro codigo; FALSE si acepto una sugerencia |
| `revisor_id` | varchar | NO |  |  | Subject de Keycloak del revisor |
| `updated_at` | timestamptz | NO | `now()` |  | Ultima modificacion del borrador |
| `posicion` | smallint | SI |  |  | Posicion (1 a 5) de la sugerencia aceptada. NULL si se corrigio |
| `sugerencias_mostradas` | smallint | SI |  |  | Cuantas sugerencias vio el revisor (0 a 5; 0 si la IA se abstuvo) |

**Restricciones, indices y permisos:**

- PK compuesta: (run_id, codigo_traductor)
- CHECK `cie10_revision_item_selection_chk`: `(corregido = true AND posicion IS NULL AND (sugerencias_mostradas IS NULL OR sugerencias_mostradas >= 0 AND sugerencias_mostradas <= 5) OR corregido = false AND posicion >= 1 AND posicion <= 5 AND sugerencias_mostradas >= posicion AND sugerencias_mostradas <= 5)`
- Indice `ix_cie10_revision_item_run`: `(run_id, codigo_traductor)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_lote_confirmacion`

Aceptacion de la clausula y confirmacion masiva de un lote CIE-10. Una fila por corrida.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `run_id` | uuid | NO |  | PK, FK -> `cie10_run.run_id` | Corrida (lote) |
| `clausula_version` | varchar(40) | NO |  | FK -> `cie10_clausula.version` | Clausula aceptada |
| `aceptada_por` | varchar | NO |  |  | Subject de Keycloak de quien acepto la clausula |
| `aceptada_en` | timestamptz | NO | `now()` |  | Cuando se acepto la clausula |
| `confirmada_por` | varchar | SI |  |  | Subject de Keycloak de quien confirmo el lote. NULL mientras no se confirme |
| `confirmada_en` | timestamptz | SI |  |  | Cuando se confirmo el lote |
| `total_registros` | integer | SI |  |  | Registros confirmados |
| `csv_object_key` | text | SI |  |  | Clave del CSV exportado del lote en el almacenamiento de objetos |
| `csv_sha256` | char(64) | SI |  |  | SHA-256 del CSV exportado |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_clausula`

Clausulas que el revisor acepta antes de revisar un lote CIE-10 asistido por IA. Solo una activa.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `version` | varchar(40) | NO |  | PK | Identificador de la clausula |
| `texto` | text | NO |  |  | Texto que acepta el revisor |
| `activa` | boolean | NO | `false` |  | TRUE en la clausula vigente. Indice unico parcial: una sola activa |
| `created_at` | timestamptz | NO | `now()` |  | Creacion de la clausula |

**Restricciones, indices y permisos:**

- Indice `ux_cie10_clausula_activa`: `UNIQUE (activa) WHERE activa = true`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_rag_version`

Version del corpus RAG de CIE-10 (catalogo institucional + referencia externa) con sus embeddings. Solo una puede estar ACTIVE.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `rag_version` | varchar(80) | NO |  | PK | Identificador de la version |
| `estado` | varchar(20) | NO | `'BUILDING'` |  | BUILDING \| READY \| ACTIVE \| FAILED \| ARCHIVED. Indice unico parcial: una sola ACTIVE |
| `institutional_sha256` | char(64) | NO |  |  | SHA-256 del CSV del catalogo institucional usado |
| `reference_sha256` | char(64) | SI |  |  | SHA-256 de la referencia CIE-10 externa usada. NULL si no se uso |
| `reference_commit` | varchar(64) | SI |  |  | Commit de la referencia externa usada |
| `embedding_model` | varchar(100) | NO |  |  | Modelo de embeddings |
| `embedding_dimensions` | integer | NO |  |  | Dimensiones de los vectores (1 a 4096) |
| `vector_count` | integer | NO | `0` |  | Vectores generados |
| `metadata_json` | jsonb | NO | `'{}'` |  | Metadatos de la construccion |
| `created_at` | timestamptz | NO | `now()` |  | Inicio de la construccion |
| `activated_at` | timestamptz | SI |  |  | Cuando paso a ACTIVE |

**Restricciones, indices y permisos:**

- CHECK `cie10_rag_version_embedding_dimensions_check`: `(embedding_dimensions >= 1 AND embedding_dimensions <= 4096)`
- CHECK `cie10_rag_version_estado_check`: `(estado = ANY ('BUILDING', 'READY', 'ACTIVE', 'FAILED', 'ARCHIVED'))`
- Indice `ux_cie10_rag_active`: `UNIQUE (estado) WHERE estado::text = 'ACTIVE'::text`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `cie10_rag_catalogo`

Codigos CIE-10 del corpus RAG de una version. Se reemplaza completo al reconstruir la version.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `rag_version` | varchar(80) | NO |  | PK, FK -> `cie10_rag_version.rag_version` | Version del corpus |
| `codigo` | varchar(8) | NO |  | PK | Codigo CIE-10 |
| `descripcion` | text | NO |  |  | Nombre institucional, o el de la referencia si no esta en el catalogo |
| `codigo_interno` | varchar | SI |  |  | Codigo interno del catalogo institucional. NULL si solo esta en la referencia |
| `en_catalogo_institucional` | boolean | NO |  |  | TRUE si el codigo existe en el catalogo institucional |
| `en_referencia_externa` | boolean | NO |  |  | TRUE si el codigo existe en la referencia CIE-10 externa |
| `descripcion_normalizada` | text | SI |  |  | descripcion en minusculas y sin tildes, para busqueda |
| `nivel` | smallint | SI |  |  | Nivel jerarquico del codigo en la CIE-10 |
| `parent_codigo` | varchar(8) | SI |  |  | Codigo padre en la jerarquia |
| `ancestros` | jsonb | NO | `'[]'` |  | Arreglo JSON de codigos ancestros |
| `source` | varchar(120) | SI |  |  | Origen del registro (catalogo institucional o referencia) |
| `texto_busqueda_normalizado` | text | SI |  |  | Nombre, descripcion de referencia y jerarquia normalizados; corpus de la busqueda lexica hibrida |

**Restricciones, indices y permisos:**

- PK compuesta: (rag_version, codigo)
- FK `cie10_rag_catalogo_rag_version_fkey`: (rag_version) -> `cie10_rag_version`(rag_version), ON DELETE CASCADE
- Indice `ix_cie10_rag_catalogo_codigo`: `(codigo)`
- Indice `ix_cie10_rag_catalogo_descripcion`: `(rag_version, descripcion_normalizada)`
- Indice `ix_cie10_rag_catalogo_parent`: `(rag_version, parent_codigo)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Catalogos

### `signo_catalogo`

Catálogo centralizado de signos de alerta disponibles en el sistema.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `signo_catalogo_id` | serial | NO | autoincremental | PK | ID numérico único |
| `nombre_normalizado` | varchar(200) | NO |  |  | Nombre normalizado del signo |
| `categoria` | varchar(100) | SI |  |  | Categoría médica del signo |
| `descripcion_medica` | text | SI |  |  | Descripción clínica detallada |
| `activo` | boolean | NO | `true` |  | Indicador de disponibilidad (default: true) |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de creación |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `examen_catalogo`

Catálogo centralizado de exámenes disponibles.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `examen_catalogo_id` | serial | NO | autoincremental | PK | ID numérico único |
| `nombre_normalizado` | varchar(200) | NO |  |  | Nombre normalizado del examen |
| `tipo` | varchar(50) | SI |  |  | GENETICO \| IMAGEN \| LABORATORIO \| FUNCIONAL |
| `descripcion` | text | SI |  |  | Descripción del examen |
| `activo` | boolean | NO | `true` |  | Indicador de disponibilidad (default: true) |
| `fecha_creacion` | timestamptz | NO | `now()` |  | Timestamp de creación |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `region_anatomica`

Agrupación anatómica de alto nivel. Cada región contiene N partes del cuerpo.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `region_id` | smallserial | NO | autoincremental | PK | ID numérico único (autogenerado) |
| `nombre` | varchar(50) | NO |  | UNIQUE | Nombre de la región (ej: Cabeza y cuello, Tronco) |
| `orden` | smallint | NO |  |  | Orden de presentación en la UI |
| `activo` | boolean | NO | `true` |  | Indicador de disponibilidad (default: true) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `parte_del_cuerpo`

Partes anatómicas del cuerpo, organizadas por región. Indica si la parte requiere lateralidad y si admite línea media.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `parte_id` | smallserial | NO | autoincremental | PK | ID numérico único (autogenerado) |
| `region_id` | smallint | NO |  | FK -> `region_anatomica.region_id` | Región anatómica a la que pertenece (FK → `region_anatomica`) |
| `nombre` | varchar(50) | NO |  |  | Nombre de la parte (ej: Ojos, Manos, Pies) |
| `orden` | smallint | NO | `0` |  | Orden dentro de la región (default: 0) |
| `requiere_lateralidad` | boolean | NO | `true` |  | Si `true`, el médico debe especificar lateralidad al registrar un signo |
| `permite_linea_media` | boolean | NO | `true` |  | Si `true`, la opción "Línea media" es válida para esta parte |
| `activo` | boolean | NO | `true` |  | Indicador de disponibilidad (default: true) |

**Restricciones, indices y permisos:**

- Indice `uq_parte_region_nombre`: `UNIQUE (region_id, nombre)`
- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `lateralidad`

Catálogo de opciones de lateralidad aplicables al registro de signos de alerta.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `lateralidad_id` | smallserial | NO | autoincremental | PK | ID numérico único (autogenerado) |
| `codigo` | varchar(10) | NO |  | UNIQUE | Código corto: `NA` \| `DER` \| `IZQ` \| `BILAT` \| `MID` |
| `nombre` | varchar(20) | NO |  | UNIQUE | Nombre descriptivo: No aplica \| Derecha \| Izquierda \| Bilateral \| Línea media |
| `orden` | smallint | NO |  |  | Orden de presentación |
| `activo` | boolean | NO | `true` |  | Indicador de disponibilidad (default: true) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `referido_de`

Catálogo de fuentes de referencia para pacientes.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `referido_de_id` | smallint | NO |  | PK | ID numérico único |
| `nombre` | varchar(100) | NO |  |  | Nombre de la fuente (ej: Hospital X, Clínica Y, Autorreferencia) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `asistencia_parto`

Catálogo de tipos de asistencia médica en el parto.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `asistencia_parto_id` | smallint | NO |  | PK | ID numérico único |
| `nombre` | varchar(100) | NO |  |  | Nombre del tipo (ej: Parto Vaginal, Cesárea, Forceps) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `familiar_catalogo`

Catálogo de tipos de relaciones familiares para registro de familiares afectados.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `familiar_catalogo_id` | smallint | NO |  | PK | ID numérico único |
| `nombre` | varchar(100) | NO |  | UNIQUE | Tipo de relación (ej: MADRE, PADRE, HERMANO_A, ABUELO_MATERNO, ABUELA_MATERNA, ABUELO_PATERNO, ABUELA_PATERNA, TIO_MATERNO, TIA_MATERNA, TIO_PATERNO, TIA_PATERNA, PRIMO_A, OTRO_FAMILIAR) |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

### `sexo_catalogo`

Catalogo de sexo del paciente.

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `sexo_id` | smallint | NO |  | PK | ID del catalogo |
| `codigo` | varchar(1) | NO |  | UNIQUE | M \| F \| I |
| `nombre` | varchar(50) | NO |  |  | Masculino \| Femenino \| Indeterminado |
| `activo` | boolean | NO | `true` |  | FALSE lo oculta en el formulario |
| `orden` | smallint | NO |  |  | Orden de despliegue |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: DELETE, INSERT, SELECT, UPDATE

---

## Control de migraciones

### `schema_migrations`

Migraciones aplicadas por el servicio migrate (local) o make migrate (AWS).

| Campo | Tipo | Nulo | Default | Clave | Descripcion |
|-------|------|------|---------|-------|-------------|
| `version` | varchar(200) | NO |  | PK | Nombre del archivo NN_*.sql aplicado |
| `applied_at` | timestamptz | NO | `now()` |  | Cuando se aplico |

**Restricciones, indices y permisos:**

- Permisos: `congenia_app`: SELECT

---

## Seguridad

### Roles

| Rol | Login | Superusuario | Uso |
|-----|-------|--------------|-----|
| `congenia` | SI | SI | Propietario. Lo usa `migrate`. |
| `congenia_app` | NO (la contrasena la asigna `migrate` con APP_DB_PASSWORD) | NO | API, PDF worker y batch CIE-10. Solo INSERT/SELECT en la bitacora. |

Privilegios por defecto (objetos nuevos):

- secuencias creadas por `congenia`: `{congenia_app=rU/congenia}`
- tablas creadas por `congenia`: `{congenia_app=arwd/congenia}`

### Funciones

| Funcion | Devuelve | Lenguaje | Descripcion |
|---------|----------|----------|-------------|
| `auditoria_evento_encadenar()` | `trigger` | plpgsql |  |
| `auditoria_evento_hash(e auditoria_evento)` | `character` | sql |  |
| `bloquear_modificacion_auditoria()` | `trigger` | plpgsql |  |
| `ficha_provisional_no_truncate()` | `trigger` | plpgsql |  |
| `ficha_provisional_validar()` | `trigger` | plpgsql |  |
| `verificar_cadena_auditoria(desde_secuencia bigint)` | `TABLE(ok boolean, filas_verificadas bigint, primera_secuencia_rota bigint, motivo text)` | plpgsql |  |

### Triggers

| Tabla | Trigger | Definicion |
|-------|---------|------------|
| `auditoria_evento` | `trg_auditoria_evento_encadenar` | `BEFORE INSERT ON auditoria_evento FOR EACH ROW EXECUTE FUNCTION auditoria_evento_encadenar()` |
| `auditoria_evento` | `trg_auditoria_evento_inmutable` | `BEFORE DELETE OR UPDATE ON auditoria_evento FOR EACH ROW EXECUTE FUNCTION bloquear_modificacion_auditoria()` |
| `auditoria_evento` | `trg_auditoria_evento_no_truncate` | `BEFORE TRUNCATE ON auditoria_evento FOR EACH STATEMENT EXECUTE FUNCTION bloquear_modificacion_auditoria()` |
| `ficha_cambio` | `trg_ficha_cambio_inmutable` | `BEFORE DELETE OR UPDATE ON ficha_cambio FOR EACH ROW EXECUTE FUNCTION bloquear_modificacion_auditoria()` |
| `ficha_cambio` | `trg_ficha_cambio_no_truncate` | `BEFORE TRUNCATE ON ficha_cambio FOR EACH STATEMENT EXECUTE FUNCTION bloquear_modificacion_auditoria()` |
| `ficha_provisional` | `trg_ficha_provisional_no_truncate` | `BEFORE TRUNCATE ON ficha_provisional FOR EACH STATEMENT EXECUTE FUNCTION ficha_provisional_no_truncate()` |
| `ficha_provisional` | `trg_ficha_provisional_validar` | `BEFORE INSERT OR DELETE OR UPDATE ON ficha_provisional FOR EACH ROW EXECUTE FUNCTION ficha_provisional_validar()` |

### Tipos de evento de auditoria

Valores de `tipo_evento_catalogo` (FK de `auditoria_evento.tipo_evento`).

| Codigo | Categoria | Descripcion |
|--------|-----------|-------------|
| `ACCESO_API` | ACCESO | Solicitud atendida por la API |
| `ACCESO_DENEGADO` | ACCESO | Solicitud rechazada por autenticacion o autorizacion (401/403) |
| `FIRMA_EVIDENCIA_MIGRADA` | ARCHIVO | Firma de un consentimiento historico movida de la base a S3 |
| `PDF_CONSENTIMIENTO_GENERADO` | ARCHIVO | PDF del consentimiento generado y almacenado |
| `URL_PREFIRMADA_GENERADA` | ARCHIVO | Emision de una URL prefirmada de subida |
| `CATALOGO_MODIFICADO` | CATALOGO | Alta, cambio o baja en un catalogo clinico |
| `ADENDA_BUSQUEDA` | CONSULTA | Busqueda en la bandeja de adendas |
| `AGENT_QUERY_EXECUTED` | CONSULTA | Consulta agregada de reportería ejecutada por el agente |
| `AGENT_QUERY_FAILED` | CONSULTA | Consulta agregada de reportería fallida o bloqueada |
| `FICHA_BUSQUEDA` | CONSULTA | Busqueda de fichas en el dashboard |
| `FICHA_LEIDA` | CONSULTA | Lectura del detalle de una ficha clinica |
| `FICHA_LISTADA` | CONSULTA | Listado de fichas de un paciente o pendientes |
| `CONSOLIDACION_EJECUTADA` | INTEGRACION | Resumen de una corrida del batch de consolidacion de fichas provisionales |
| `FICHA_PROVISIONAL_EN_REVISION` | INTEGRACION | La HC buscada aparecio en SADC y se creo la adenda de consolidacion |
| `SESION_INTEGRACION_ACTIVADA` | INTEGRACION | Apertura del formulario de captura |
| `SESION_INTEGRACION_CREADA` | INTEGRACION | Sesion de captura iniciada por un sistema externo |
| `SESION_INTEGRACION_MANUAL` | INTEGRACION | Sesion de captura iniciada manualmente por un medico |
| `ADENDA_SOLICITADA` | MODIFICACION | Creacion de una adenda sobre una ficha vigente |
| `CONSENTIMIENTO_FIRMADO` | MODIFICACION | Registro del consentimiento informado firmado |
| `FICHA_CREADA` | MODIFICACION | Alta de una ficha clinica |
| `FICHA_PROVISIONAL_CREADA` | MODIFICACION | Ficha registrada con historia clinica provisional porque la HC no existe en SADC |
| `ADENDA_RESUELTA` | VALIDACION | Resolucion de una adenda (aprobada o rechazada) |
| `ALERTA_VALIDADA` | VALIDACION | Decision del revisor sobre un signo de alerta o examen de una adenda |
| `CIE10_BORRADOR_ACEPTADO` | VALIDACION | Aceptacion preliminar de una sugerencia del lote CIE-10 |
| `CIE10_BORRADOR_CORREGIDO` | VALIDACION | Correccion preliminar de un registro del lote CIE-10 |
| `CIE10_CLAUSULA_ACEPTADA` | VALIDACION | Aceptacion de clausula para revision CIE-10 asistida por IA |
| `CIE10_DECISION_CORREGIDA` | VALIDACION | Correccion de una decision CIE-10 existente |
| `CIE10_DECISION_FALLIDA` | VALIDACION | Intento fallido de decision o correccion CIE-10 |
| `CIE10_DECISION_REGISTRADA` | VALIDACION | Primera decision de correccion CIE-10 |
| `CIE10_LOTE_CONFIRMACION_FALLIDA` | VALIDACION | Intento fallido de confirmacion masiva CIE-10 |
| `CIE10_LOTE_CONFIRMADO` | VALIDACION | Confirmacion masiva de un lote CIE-10 revisado |
| `FICHA_PROVISIONAL_CONSOLIDADA` | VALIDACION | Revisor aprobo la consolidacion de la ficha provisional con la HC real |
| `FICHA_PROVISIONAL_DESCARTADA` | VALIDACION | Revisor descarto la consolidacion de la ficha provisional |
| `OBSERVACION_VALIDADA` | VALIDACION | Decision del revisor sobre una observacion de una adenda |
