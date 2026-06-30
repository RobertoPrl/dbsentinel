-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 03_automatizacion_y_triggers.sql
-- Finalidad: Implementación de lógica reactiva para auditoría y validación
-- ============================================================================

-- ============================================================================
-- 1. ACTUALIZACIONES AUTOMÁTICAS (Campos de Auditoría Temporal)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_set_actualizado_en()
-- ------------------------------------------------------------
-- Finalidad:
-- Actualizar automáticamente el campo actualizado_en cada vez que
-- se modifica una fila.
--
-- Tipo de trigger previsto:
-- BEFORE UPDATE.
--
-- Por qué es BEFORE:
-- Porque se modifica el valor de NEW.actualizado_en antes de que
-- PostgreSQL guarde definitivamente la fila.
--
-- NEW:
-- Representa la nueva versión de la fila en un INSERT o UPDATE.
--
-- [Comentario Extra]: Inicialización de la rutina global de marcas de tiempo
CREATE OR REPLACE FUNCTION app.trg_set_actualizado_en()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
-- Se sustituye el valor de actualizado_en por la fecha y hora actual.
NEW.actualizado_en := now();

-- En un trigger BEFORE UPDATE hay que devolver NEW para que PostgreSQL
-- continúe guardando la fila modificada.
RETURN NEW;
END;
$$;

-- Cada vez que se actualice un alumno, se actualizará automáticamente actualizado_en.
-- [Comentario Extra]: Enlace de auditoría sobre el componente maestro de alumnos
CREATE TRIGGER set_actualizado_alumnos
BEFORE UPDATE ON app.alumnos
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();

-- [Comentario Extra]: Enlace de auditoría sobre el componente maestro de cursos
CREATE TRIGGER set_actualizado_cursos
BEFORE UPDATE ON app.cursos
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();

-- [Comentario Extra]: Enlace de auditoría sobre las inscripciones operativas
CREATE TRIGGER set_actualizado_matriculas
BEFORE UPDATE ON app.matriculas
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();

-- [Comentario Extra]: Enlace de auditoría sobre los registros de asistencia diaria
CREATE TRIGGER set_actualizado_asistencia
BEFORE UPDATE ON app.asistencia
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();

-- [Comentario Extra]: Enlace de auditoría sobre el reporte de incidencias críticas
CREATE TRIGGER set_actualizado_incidencias
BEFORE UPDATE ON app.incidencias
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();

-- [Comentario Extra]: Enlace de auditoría sobre la cola de tareas pendientes
CREATE TRIGGER set_actualizado_tareas
BEFORE UPDATE ON app.tareas_pendientes
FOR EACH ROW
EXECUTE FUNCTION app.trg_set_actualizado_en();


-- ============================================================================
-- 2. NORMALIZACIÓN DE DATOS (Rutinas de Calidad de la Información)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_normalizar_email_alumno()
-- ------------------------------------------------------------
-- Finalidad:
-- Guardar siempre los correos de alumnos en minúsculas y sin espacios
-- al principio o al final.
--
-- Tipo de trigger previsto:
-- BEFORE INSERT OR UPDATE OF email.
--
-- Ventaja:
-- Evita duplicidades aparentes como:
-- ANA@EXAMPLE.COM
-- ana@example.com
-- ' ana@example.com '
--
-- [Comentario Extra]: Rutina defensiva para preservar la integridad del índice único de contactos
CREATE OR REPLACE FUNCTION app.trg_normalizar_email_alumno()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
-- btrim elimina espacios al inicio y al final.
-- lower convierte el texto a minúsculas.
NEW.email := lower(btrim(NEW.email));

-- Devuelve la fila corregida antes de insertarla o actualizarla.
RETURN NEW;
END;
$$;

-- [Comentario Extra]: Trigger reactivo para el campo específico de correo electrónico
CREATE TRIGGER normalizar_email_alumno
BEFORE INSERT OR UPDATE OF email ON app.alumnos
FOR EACH ROW
EXECUTE FUNCTION app.trg_normalizar_email_alumno();


-- ============================================================================
-- 3. REGLAS DE CONTROL ACADÉMICO (Validaciones de Negocio en Tiempo de Ejecución)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_validar_curso()
-- ------------------------------------------------------------
-- Finalidad:
-- Validar reglas de negocio antes de crear o modificar un curso.
--
-- Tipo de trigger previsto:
-- BEFORE INSERT OR UPDATE ON app.cursos.
--
-- Validaciones:
-- 1. La fecha de fin no puede ser anterior a la fecha de inicio.
-- 2. Un curso no puede marcarse como en_curso si todavía no ha empezado.
--
-- RAISE EXCEPTION:
-- Cancela la operación y muestra un mensaje de error personalizado.
--
-- [Comentario Extra]: Enmascaramiento de restricciones lógicas avanzadas previas a la persistencia
CREATE OR REPLACE FUNCTION app.trg_validar_curso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
-- Validación 1: la fecha de finalización debe ser igual o posterior
-- a la fecha de inicio.
IF NEW.fecha_fin < NEW.fecha_inicio THEN
RAISE EXCEPTION 'La fecha de fin (%) no puede ser anterior a la fecha de inicio (%)',
NEW.fecha_fin, NEW.fecha_inicio;
END IF;

-- Validación 2: no se permite marcar como en curso un curso futuro.
IF NEW.estado = 'en_curso' AND NEW.fecha_inicio > CURRENT_DATE THEN
RAISE EXCEPTION 'No se puede marcar en_curso un curso que empieza en el futuro';
END IF;

-- Si todas las validaciones se cumplen, se permite guardar la fila.
RETURN NEW;
END;
$$;

-- [Comentario Extra]: Activación del motor de restricciones lógicas sobre el catálogo educativo
CREATE TRIGGER validar_curso
BEFORE INSERT OR UPDATE ON app.cursos
FOR EACH ROW
EXECUTE FUNCTION app.trg_validar_curso();
