# CONGENIA - Stack de Orquestación

Stack unificado para el proyecto CONGENIA que orquesta los componentes principales:

- **CONGENIA-M1-SERVER**: API Backend (Express.js + PostgreSQL)
- **CONGENIA-M1**: Frontend (React + Vite + TypeScript)
- **CONGENIA-M1-PDF-WORKER**: Worker asíncrono (RabbitMQ + PDF + SeaweedFS)
- **Keycloak**: proveedor OAuth con realm `congenia` horneado en imagen propia

Este repositorio orquesta el **entorno local de desarrollo** con Docker
Compose. El despliegue en AWS vive en `CONGENIA-INFRA`, y desde que cada
servicio publica su imagen por GitHub Actions, aquí no se construye nada para
producción.

- Levantar AWS desde cero: `CONGENIA-INFRA/BOOTSTRAP.md`
- Ciclo de despliegue: `CONGENIA-INFRA/HERE.md`
- El contrato de la ficha clínica: [PROMPT.md](PROMPT.md) y
  [REQUEST.md](REQUEST.md)

## Índice

- [Requisitos](#requisitos)
- [Inicio Rápido](#inicio-rápido)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Configuración](#configuración)
- [RabbitMQ](#rabbitmq)
- [PDF Worker](#pdf-worker)
- [Uso Local](#uso-local)
- [Pruebas Worker](#pruebas-worker)
- [Scripts de Ayuda](#scripts-de-ayuda)

---

## Requisitos

- Docker 24.0+
- Docker Compose v2.20+
- Git

Verificar versiones:
```bash
docker --version
docker compose version
```

---

## Inicio Rápido

```bash
# 1. Clonar el repositorio (si aún no lo tienes)
git clone <url-del-repo> ProjectUVG
cd ProjectUVG

# 2. Copiar archivo de variables de entorno
cp .env.example .env

# 3. Editar .env con los secretos requeridos (ver tabla de configuración)
nano .env  # o tu editor preferido

# 4. Levantar el stack
docker compose up -d

# 5. Verificar que los servicios estén corriendo
docker compose ps

# 6. Ver logs
docker compose logs -f
```

Acceder a:
- **Frontend**: http://localhost:8080
- **API**: http://localhost:3000
- **API Docs**: http://localhost:3000/docs
- **Playground (dev profile)**: http://localhost:5173
- **Base de datos**: localhost:5432
- **SeaweedFS Master**: http://localhost:9333
- **SeaweedFS S3**: http://localhost:8333
- **RabbitMQ Management UI**: `http://localhost:${RABBITMQ_MANAGEMENT_PORT}` (default `15672`)
- **RabbitMQ AMQP**: `localhost:${RABBITMQ_AMQP_PORT}` (default `5672`)

---

## Estructura del Proyecto

```
ProjectUVG/
├── CONGENIA-DB/                 # Esquemas de base de datos
│   └── schema/
│       └── Congenia.sql
├── CONGENIA-M1-SERVER/          # API Backend
│   ├── Dockerfile
│   ├── db/init/                 # Scripts de inicialización DB
│   └── src/
├── CONGENIA-M1/                 # Frontend
│   ├── Dockerfile
│   ├── nginx.conf
│   └── src/
├── CONGENIA-M1-PDF-WORKER/      # Worker PDF (RabbitMQ -> PDF -> S3 -> DB)
│   ├── Dockerfile
│   └── src/
├── keycloak/                    # Imagen propia con el realm horneado
│   ├── Dockerfile
│   ├── VERSION
│   └── realm-congenia.json
├── scripts/                     # Scripts de ayuda
│   ├── release-plan.sh          # Plan de publicación de imágenes (escape hatch)
│   ├── health-check.sh          # Verificar salud del stack
│   └── publish_test.ts          # Publicar evento de prueba para PDF worker
├── docker-compose.yml           # Entorno local (build desde código)
├── .env.example                 # Plantilla de variables
├── PROMPT.md                    # Contrato de la ficha clínica
├── REQUEST.md                   # Referencia de POST /v1/patient
└── README.md                    # Este archivo
```

---

## Configuración

### Variables de Entorno

Copiar `.env.example` a `.env` y configurar:

| Variable | Descripción | Requerido | Default |
|----------|-------------|-----------|---------|
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL | **Sí** | - |
| `POSTGRES_DB` | Nombre de la base de datos | No | `congenia` |
| `POSTGRES_USER` | Usuario de PostgreSQL | No | `congenia` |
| `POSTGRES_PORT` | Puerto externo de PostgreSQL | No | `5432` |
| `APP_ENCRYPTION_KEY` | 64 caracteres hex para capabilities y PHI | **Sí** | - |
| `REDIS_PASSWORD` | Contraseña de Redis local | **Sí** | - |
| `KEYCLOAK_ADMIN_PASSWORD` | Contraseña admin local de Keycloak | **Sí** | - |
| `KEYCLOAK_SADC_CLIENT_SECRET` | Secret del cliente OAuth `sadc` | **Sí** | - |
| `KEYCLOAK_MEDICO_INITIAL_PASSWORD` | Password temporal de `medico.inicial` | **Sí** | - |
| `RABBITMQ_DEFAULT_USER` | Usuario administrador de RabbitMQ | **Sí** | - |
| `RABBITMQ_DEFAULT_PASS` | Contraseña administradora de RabbitMQ | **Sí** | - |
| `RABBITMQ_DEFAULT_VHOST` | Virtual host por defecto en RabbitMQ | No | `/` |
| `RABBITMQ_AMQP_PORT` | Puerto externo AMQP de RabbitMQ | No | `5672` |
| `RABBITMQ_MANAGEMENT_PORT` | Puerto externo de RabbitMQ Management UI | No | `15672` |
| `RABBITMQ_QUEUE_MAIN` | Cola principal del worker PDF | No | `consent.pdf.generate` |
| `RABBITMQ_QUEUE_DLQ` | Cola DLQ del worker PDF | No | `consent.pdf.generate.dlq` |
| `WORKER_PREFETCH` | Prefetch del consumidor RabbitMQ | No | `3` |
| `WORKER_MAX_RETRIES` | Reintentos máximos antes de DLQ | No | `5` |
| `WORKER_RETRY_BACKOFF_MS` | Backoff base de retry (ms) | No | `2000` |
| `WORKER_RETRY_BACKOFF_MULTIPLIER` | Multiplicador exponencial de retry | No | `2` |
| `S3_ENDPOINT` | Endpoint S3 de SeaweedFS | No | `http://seaweedfs:8333` |
| `S3_BUCKET` | Bucket de documentos | No | `congenia-docs` |
| `S3_REGION` | Región S3 compatible | No | `us-east-1` |
| `S3_ACCESS_KEY_ID` | Access key para S3 | No | `congenia` |
| `S3_SECRET_ACCESS_KEY` | Secret key para S3 | No | `congenia` |
| `API_PORT` | Puerto externo de la API | No | `3000` |
| `FRONTEND_PORT` | Puerto externo del frontend | No | `8080` |
| `CORS_ORIGINS` | Orígenes permitidos para CORS | **Sí** | `http://localhost:8080` |
| `API_BASE_URL` | URL runtime de la API para el frontend | No | `http://localhost:3000` |
| `VITE_OIDC_AUTHORITY` | URL del servidor OIDC | No | - |
| `VITE_OIDC_CLIENT_ID` | Client ID para OAuth | No | - |
| `VITE_FHIR_BASE_URL` | URL del servidor FHIR | No | - |

### Ejemplo de .env Mínimo

```bash
POSTGRES_PASSWORD=mi_contraseña_segura_123
APP_ENCRYPTION_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
REDIS_PASSWORD=mi_contraseña_redis_123
KEYCLOAK_ADMIN_PASSWORD=mi_contraseña_keycloak_123
KEYCLOAK_SADC_CLIENT_SECRET=mi_secret_sadc_123
KEYCLOAK_MEDICO_INITIAL_PASSWORD=mi_contraseña_medico_123
RABBITMQ_DEFAULT_USER=congenia
RABBITMQ_DEFAULT_PASS=mi_contraseña_rabbitmq_123
S3_ACCESS_KEY_ID=congenia
S3_SECRET_ACCESS_KEY=congenia
```

---

## RabbitMQ

RabbitMQ se despliega como broker de mensajería con persistencia de datos (`congenia_rabbitmq_data`).

Puertos:
- **AMQP interno**: `5672`
- **AMQP host**: `localhost:${RABBITMQ_AMQP_PORT}` (default `5672`)
- **Management UI interno**: `15672`
- **Management UI host**: `http://localhost:${RABBITMQ_MANAGEMENT_PORT}` (default `15672`)

Credenciales:
- Usuario: `RABBITMQ_DEFAULT_USER` (**requerido**)
- Contraseña: `RABBITMQ_DEFAULT_PASS` (**requerido**)
- VHost: `RABBITMQ_DEFAULT_VHOST` (default `/`)

Ejemplo de conexión AMQP:

```bash
amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@rabbitmq:5672/${RABBITMQ_DEFAULT_VHOST}
```

---

## PDF Worker

`pdf_worker` consume eventos de `consent.pdf.generate`, genera el PDF de consentimiento y actualiza `consentimiento.pdf_ref` + `consentimiento.pdf_hash_sha256`.

Comportamiento actual (worker-only):
- No existe endpoint de finalización en backend/frontend para este flujo en esta fase.
- El disparo del proceso se realiza por mensaje RabbitMQ (`scripts/publish_test.ts`).

Colas:
- Principal: `consent.pdf.generate`
- DLQ: `consent.pdf.generate.dlq`

Salida esperada:
- PDF en `congenia-docs/consents/<ficha_id>/<consentimiento_id>/<jobId>.pdf`
- Registro actualizado en tabla `consentimiento`.

---

## Uso Local

### Comandos Principales

```bash
# Levantar todos los servicios
docker compose up -d

# Ver estado de servicios
docker compose ps

# Ver logs en tiempo real
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f api

# Ver logs del PDF worker
docker compose logs -f pdf_worker

# Detener servicios
docker compose down

# Detener y eliminar volúmenes (reset de BD)
docker compose down -v

# Reconstruir imágenes
docker compose build

# Reconstruir y levantar
docker compose up -d --build

# Levantar playground de desarrollo (Vite) en perfil dev
docker compose --profile dev up -d playground
```

### Verificación de Salud

```bash
# Verificar healthchecks
docker compose ps

# Probar API
curl http://localhost:3000/health

# Probar Frontend
curl http://localhost:8080/health

# Probar RabbitMQ Management UI
curl http://localhost:15672

# Verificar RabbitMQ dentro del contenedor
docker compose exec rabbitmq rabbitmq-diagnostics -q ping

# Ver estado del PDF worker
docker compose ps pdf_worker

# Conectar a PostgreSQL
docker compose exec postgres psql -U congenia -d congenia
```

### Desarrollo

Para desarrollo activo, puedes usar volúmenes montados. Crear un archivo `docker-compose.override.yml`:

```yaml
services:
  api:
    volumes:
      - ./CONGENIA-M1-SERVER/src:/app/src:ro
    command: npm run dev

  frontend:
    build:
      target: builder
    volumes:
      - ./CONGENIA-M1/src:/app/src:ro
    ports:
      - "5173:5173"
    command: pnpm dev --host
```

---

## Pruebas Worker

### 1. Levantar dependencias del flujo asíncrono

```bash
docker compose up -d postgres rabbitmq seaweedfs pdf_worker
```

### 2. Publicar evento de prueba

```bash
npx tsx scripts/publish_test.ts --consentimiento-id <CONSENTIMIENTO_UUID> --ficha-id <FICHA_UUID>
```

Si no pasas UUIDs, el script genera valores aleatorios (útil para probar ruta hacia DLQ).

### 3. Verificar procesamiento

```bash
# Logs del worker
docker compose logs -f pdf_worker

# Verificar update en DB
docker compose exec -T postgres psql -U congenia -d congenia -c \
"SELECT consentimiento_id, ficha_id, pdf_ref, pdf_hash_sha256 FROM consentimiento WHERE consentimiento_id = '<CONSENTIMIENTO_UUID>';"
```

---

## Scripts de Ayuda

### release-plan.sh
Calcula qué tag le toca a cada servicio y comprueba si ya existe en ECR.

```bash
./scripts/release-plan.sh
./scripts/release-plan.sh --write ../CONGENIA-INFRA/envs/aws/images.tfvars
```

Es la válvula de escape para publicar sin pasar por GitHub —una cuenta AWS
nueva, una depuración—. En el camino normal no hace falta: el workflow
`publish-image` de cada repositorio publica al mergear y abre el PR que
registra la versión. Ambas vías calculan exactamente el mismo tag.

### health-check.sh
Verifica el estado de salud de todos los servicios del stack local.

```bash
./scripts/health-check.sh
```

### publish_test.ts
Publica un evento de prueba para el flujo de generación de PDF del worker.

```bash
npx tsx scripts/publish_test.ts --consentimiento-id <UUID> --ficha-id <UUID>
```

## Contacto y Soporte

**Issues**: Reportar problemas en GitHub Issues
