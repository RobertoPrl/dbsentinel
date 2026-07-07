-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 05_auditoria.sql
-- Finalidad: Infraestructura y triggers polimórficos de auditoría en JSONB
-- ============================================================================

-- ============================================================================
-- 1. ESTRUCTURAS DE ALMACENAMIENTO (Repositorio de Cambios Históricos)
-- ============================================================================

-- Tabulación física del histórico:
-- [Comentario Extra]: Creación de la entidad centralizada para persistencia de logs transaccionales
CREATE TABLE audit.cambios (
    cambio_id        BIGSERIAL PRIMARY KEY,
    esquema          TEXT NOT NULL,
    tabla            TEXT NOT NULL,
    operacion        TEXT NOT NULL,
    clave_primaria   JSONB,
    datos_anteriores JSONB,
    datos_nuevos     JSONB,
    usuario_bd       TEXT NOT NULL DEFAULT current_user,
    usuario_app      TEXT,
    direccion_ip     INET,
    aplicacion       TEXT,
    transaccion_id   BIGINT NOT NULL DEFAULT txid_current(),
    cambiado_en      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Plan de indexación optimizado:
-- [Comentario Extra]: Creación de estructuras B-Tree para rangos temporales y GIN para búsquedas sobre llaves JSONB
CREATE INDEX idx_audit_cambios_tabla_fecha
    ON audit.cambios (esquema, tabla, cambiado_en DESC);

CREATE INDEX idx_audit_cambios_datos_anteriores
    ON audit.cambios USING gin (datos_anteriores);

CREATE INDEX idx_audit_cambios_datos_nuevos
    ON audit.cambios USING gin (datos_nuevos);

-- ============================================================================
-- 2. LÓGICA PROCEDIMENTAL (Rutina de Captura Dinámica de Mutaciones)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: audit.trg_auditar_cambios()
-- ------------------------------------------------------------
-- Finalidad:
-- Registrar automáticamente en audit.cambios las operaciones INSERT,
-- UPDATE y DELETE realizadas sobre las tablas principales.
--
-- Tipo de trigger previsto:
-- AFTER INSERT OR UPDATE OR DELETE.
--
-- Características:
-- - Guarda el esquema y la tabla afectados.
-- - Guarda la operación realizada.
-- - Guarda la clave primaria del registro afectado.
-- - Guarda los datos anteriores y/o nuevos en formato JSONB.
-- - Guarda el usuario de base de datos y el usuario funcional de aplicación.
-- - Guarda IP, aplicación, transacción y fecha.
--
-- TG_ARGV[0]:
-- Permite pasar a la función el nombre de la columna que actúa como clave
-- primaria en cada tabla. Así esta misma función sirve para varias tablas.
--
CREATE OR REPLACE FUNCTION audit.trg_auditar_cambios()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    -- v_pk guardará la clave primaria en formato JSONB.
    v_pk JSONB;
BEGIN
    -- Caso 1: auditoría de inserciones.
    IF TG_OP = 'INSERT' THEN
        -- Se construye un JSON con la clave primaria.
        -- TG_ARGV[0] contiene el nombre de la columna clave, por ejemplo alumno_id.
        v_pk := jsonb_build_object('id', to_jsonb(NEW)->(TG_ARGV[0]));

        -- En un INSERT no hay datos anteriores, solo datos nuevos.
        INSERT INTO audit.cambios (
            esquema, tabla, operacion, clave_primaria,
            datos_anteriores, datos_nuevos,
            usuario_bd, usuario_app, direccion_ip, aplicacion
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_pk,
            NULL, to_jsonb(NEW),
            current_user, app.usuario_aplicacion(), inet_client_addr(), 
            current_setting('application_name', true)
        );

        RETURN NEW;

    -- Caso 2: auditoría de modificaciones.
    ELSIF TG_OP = 'UPDATE' THEN
        -- En un UPDATE usamos NEW para obtener la clave actualizada.
        v_pk := jsonb_build_object('id', to_jsonb(NEW)->(TG_ARGV[0]));

        -- Se guardan tanto los valores anteriores como los nuevos.
        INSERT INTO audit.cambios (
            esquema, tabla, operacion, clave_primaria,
            datos_anteriores, datos_nuevos,
            usuario_bd, usuario_app, direccion_ip, aplicacion
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_pk,
            to_jsonb(OLD), to_jsonb(NEW),
            current_user, app.usuario_aplicacion(), inet_client_addr(), 
            current_setting('application_name', true)
        );

        RETURN NEW;

    -- Caso 3: auditoría de eliminaciones.
    ELSIF TG_OP = 'DELETE' THEN
        -- En un DELETE no existe NEW, por eso se usa OLD.
        v_pk := jsonb_build_object('id', to_jsonb(OLD)->(TG_ARGV[0]));

        -- En un DELETE se guardan datos anteriores, pero no datos nuevos.
        INSERT INTO audit.cambios (
            esquema, tabla, operacion, clave_primaria,
            datos_anteriores, datos_nuevos,
            usuario_bd, usuario_app, direccion_ip, aplicacion
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_pk,
            to_jsonb(OLD), NULL,
            current_user, app.usuario_aplicacion(), inet_client_addr(), 
            current_setting('application_name', true)
        );

        RETURN OLD;
    END IF;

    -- Si por algún motivo llega una operación no contemplada, se devuelve NULL.
    RETURN NULL;
END;
$$;


-- ============================================================================
-- 3. SUSCRIPCIÓN GLOBAL DE TABLAS (Activación del Motor de Auditoría)
-- ============================================================================

CREATE TRIGGER auditar_alumnos
    AFTER INSERT OR UPDATE OR DELETE ON app.alumnos
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('alumno_id');

CREATE TRIGGER auditar_cursos
    AFTER INSERT OR UPDATE OR DELETE ON app.cursos
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('curso_id');

CREATE TRIGGER auditar_matriculas
    AFTER INSERT OR UPDATE OR DELETE ON app.matriculas
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('matricula_id');

CREATE TRIGGER auditar_pagos
    AFTER INSERT OR UPDATE OR DELETE ON app.pagos
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('pago_id');

CREATE TRIGGER auditar_incidencias
    AFTER INSERT OR UPDATE OR DELETE ON app.incidencias
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('incidencia_id');

CREATE TRIGGER auditar_tareas
    AFTER INSERT OR UPDATE OR DELETE ON app.tareas_pendientes
    FOR EACH ROW
    EXECUTE FUNCTION audit.trg_auditar_cambios('tarea_id');

/*******************************************************************************
 * Auditar cambios de estado de matrícula
 * Tipo: Tabla de auditoría + función de trigger + trigger
 * Objetivo: Registrar en una tabla de auditoría los cambios de estado de una matrícula.
 * Crear la tabla audit.ej_cambios_estado_matricula, la función 
 *            app.ej_trg_auditar_estado_matricula() y el trigger ej_auditar_estado_matricula. 
 *            Debe guardar un registro solo cuando OLD.estado sea distinto de NEW.estado.
 * Requisitos mínimos: 
 *  • La tabla de auditoría debe guardar: matricula_id, estado_anterior, 
 *    estado_nuevo, usuario_bd y cambiado_en. 
 *  • El trigger debe ser AFTER UPDATE OF estado ON app.matriculas. 
 *  • Debe usar IS DISTINCT FROM para comparar estados. 
 *  • Debe devolver NEW.
 *******************************************************************************/

-- PASO 1: Crear la tabla de auditoría en el esquema 'audit'
CREATE TABLE IF NOT EXISTS audit.ej_cambios_estado_matricula (
    auditoria_id BIGSERIAL PRIMARY KEY,
    matricula_id BIGINT NOT NULL,
    estado_anterior VARCHAR,
    estado_nuevo VARCHAR,
    usuario_bd VARCHAR NOT NULL,
    cambiado_en TIMESTAMP NOT NULL
);

-- PASO 2: Crear la función del trigger
CREATE OR REPLACE FUNCTION app.ej_trg_auditar_estado_matricula()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verificamos de manera segura si el estado anterior es distinto del nuevo
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
        -- Insertamos el registro histórico en la tabla de auditoría
        -- USER o CURRENT_USER guarda automáticamente el nombre del usuario de la BD conectado
        INSERT INTO audit.ej_cambios_estado_matricula (
            matricula_id, 
            estado_anterior, 
            estado_nuevo, 
            usuario_bd, 
            cambiado_en
        )
        VALUES (
            NEW.matricula_id, 
            OLD.estado, 
            NEW.estado, 
            USER, 
            NOW()
        );
    END IF;

    -- Se exige explícitamente devolver NEW (aunque sea un trigger AFTER UPDATE)
    RETURN NEW;
END;
$$;

-- PASO 3: Crear el trigger asociado a la columna 'estado'
CREATE OR REPLACE TRIGGER ej_auditar_estado_matricula
AFTER UPDATE OF estado ON app.matriculas
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_auditar_estado_matricula();

