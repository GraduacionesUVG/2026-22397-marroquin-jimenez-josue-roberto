# CONGENIA-DB

**Version:** `v0.3.0`

Documentacion de la base de datos de CONGENIA: diccionario de datos, diagrama y esquema consolidado.

> **La fuente de verdad del esquema es `CONGENIA-M1-SERVER/db/init/NN_*.sql`.** Este repositorio es
> un reflejo generado de ese esquema. No se usa para crear ni migrar bases: eso lo hace el servicio
> `migrate` (local) o `make migrate` en CONGENIA-INFRA (AWS).

<!-- sync:start -->
- **Alineado con:** `CONGENIA-M1-SERVER` `de59065` (2026-10-18)
- **Ultima migracion:** `18_cie10_empty_suggestion_correction.sql` (18 archivos, 40 tablas)
<!-- sync:end -->

## Contenido

| Archivo | Que es |
|---------|--------|
| `docs/data_dictionary.md` | Diccionario de datos: tablas, columnas, restricciones, indices, triggers, permisos, roles y tipos de evento de auditoria |
| `schema/Congenia.dbdiagram` | Diagrama en DBML para [dbdiagram.io](https://dbdiagram.io) |
| `schema/Congenia.sql` | `pg_dump --schema-only` de la base resultante de aplicar todas las migraciones |
| `docs/descripciones.json` | Descripciones de tablas y columnas que no tienen `COMMENT ON` en el server |
| `scripts/sync_from_server.py` | Regenera todo lo anterior |
| `docs/acceso_rds.md` | Como conectar pgAdmin/`psql` a la RDS de produccion por el tunel SSM (escrito a mano; el script de sync no lo toca) |

## Actualizar

Cada vez que el server agregue una migracion:

```bash
python scripts/sync_from_server.py            # usa ../ProjectUVG/CONGENIA-M1-SERVER
python scripts/sync_from_server.py --server /ruta/a/CONGENIA-M1-SERVER
```

Requiere Docker y Python 3.9+. El script levanta un `postgres:16-alpine` temporal, aplica `db/init` en
orden sobre una base vacia, inspecciona el resultado y reescribe los archivos. Al final lista las columnas
sin descripcion: agregalas a `docs/descripciones.json` (o como `COMMENT ON` en la migracion, que tiene
prioridad) y vuelve a correrlo. Despues pega `schema/Congenia.dbdiagram` en los diagramas de dbdiagram.io.

## Diagramas

[Diagrama de base de datos - prod](https://dbdiagram.io/d/Congenia-69c9e5e1fb2db18e3b316d8e)

[Diagrama de base de datos - development](https://dbdiagram.io/d/CONGENIA-DB-development-69c9e59d78c6c4bc7a96d61e)
