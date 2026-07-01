-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 08_notify.sql
-- Finalidad: Implementación de alertas en tiempo real con LISTEN y NOTIFY
-- ============================================================================

-- ============================================================================
-- 1. CAPA DE ALERTAS REACTIVAS (Mensajería Asíncrona en Tiempo Real)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_notificar_incidencia_critica()
-- ------------------------------------------------------------
-- Finalidad:
-- Enviar una notificación interna cuando se crea una incidencia crítica.
--
-- Tipo de trigger previsto:
-- AFTER INSERT ON app.incidencias.
--
-- LISTEN/NOTIFY:
-- - NOTIFY envía un aviso a un canal.
-- - LISTEN permite que otra sesión escuche ese canal.
--
-- Canal usado:
-- incidencias_criticas
--
-- [Comentario Extra]: Función que arma un texto en formato JSON y lo envía al canal de alertas
CREATE OR REPLACE FUNCTION app.trg_notificar_incidencia_critica()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    -- Texto que se enviará como contenido de la notificación.
    v_payload TEXT;
BEGIN
    -- Solo se notifica si la incidencia es crítica.
    IF NEW.prioridad = 'critica' THEN
        -- Se construye un JSON con los datos principales de la incidencia.
        v_payload := json_build_object(
            'incidencia_id', NEW.incidencia_id,
            'tipo', NEW.tipo,
            'descripcion', NEW.descripcion,
            'creado_en', NEW.creado_en
        )::TEXT;

        -- pg_notify envía la notificación al canal indicado.
        PERFORM pg_notify('incidencias_criticas', v_payload);
    END IF;

    -- Devuelve NEW para completar la inserción.
    RETURN NEW;
END;
$$;

-- [Comentario Extra]: Trigger que se ejecuta justo después de guardar una nueva incidencia
CREATE TRIGGER notificar_incidencia_critica
AFTER INSERT ON app.incidencias
FOR EACH ROW
EXECUTE FUNCTION app.trg_notificar_incidencia_critica();


-- ============================================================================
-- 2. ENTORNO DE PRUEBAS (Simulación de Sesiones en Paralelo)
-- ============================================================================

-- Sesión 1:
-- [Comentario Extra]: Comando para poner a escuchar a la aplicación receptora
-- LISTEN incidencias_criticas;

-- Sesión 2:
-- [Comentario Extra]: Inserción de prueba para hacer saltar la alerta en tiempo real
-- INSERT INTO app.incidencias (matricula_id, tipo, prioridad, descripcion)
-- VALUES (1, 'academica', 'critica', 'El alumno no puede acceder al aula virtual.');
