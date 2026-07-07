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

/*******************************************************************************
 * Actualizar automáticamente actualizado_en en cursos
 * Tipo: Función de trigger + trigger
 * Objetivo: Crear un trigger BEFORE UPDATE que modifique NEW.actualizado_en.
 * Crear la función app.ej_trg_set_actualizado_en_curso() y el trigger 
 *            ej_set_actualizado_cursos para que cualquier UPDATE sobre 
 *            app.cursos actualice automáticamente actualizado_en.
 * Requisitos mínimos: 
 *  • La función debe devolver TRIGGER. 
 *  • Debe asignar now() a NEW.actualizado_en. 
 *  • El trigger debe ser BEFORE UPDATE ON app.cursos FOR EACH ROW.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger
CREATE OR REPLACE FUNCTION app.ej_trg_set_actualizado_en_curso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Asignamos la fecha y hora actual al campo correspondiente del registro modificado
    NEW.actualizado_en := NOW();

    -- En triggers BEFORE de modificación de registros, es obligatorio retornar NEW
    RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado a la tabla
CREATE OR REPLACE TRIGGER ej_set_actualizado_cursos
BEFORE UPDATE ON app.cursos
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_set_actualizado_en_curso();


/*******************************************************************************
 * Normalizar el email del alumno
 * Tipo: Función de trigger + trigger
 * Objetivo: Modificar NEW.email antes de guardar el alumno.
 * Crear la función app.ej_trg_normalizar_email() y el trigger 
 *            ej_normalizar_email_alumno para que el email se guarde en 
 *            minúsculas y sin espacios.
 * Requisitos mínimos: 
 *  • La función debe usar lower y btrim. 
 *  • El trigger debe ejecutarse BEFORE INSERT OR UPDATE OF email ON app.alumnos. 
 *  • Debe devolver NEW.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger
CREATE OR REPLACE FUNCTION app.ej_trg_normalizar_email()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	-- Modificamos el valor entrante asegurando minúsculas y limpiando espacios
	NEW.email := LOWER(BTRIM(NEW.email));

	-- Retornamos el registro modificado para proceder con el guardado
	RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado a la tabla
CREATE OR REPLACE TRIGGER ej_normalizar_email_alumno
BEFORE INSERT OR UPDATE OF email ON app.alumnos
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_normalizar_email();

/*******************************************************************************
 * Validar que una sesión pertenece al rango de fechas del curso
 * Tipo: Función de trigger + trigger
 * Objetivo: Crear una validación automática antes de insertar o modificar sesiones.
 * Crear la función app.ej_trg_validar_fecha_sesion() y el trigger 
 *            ej_validar_fecha_sesion para impedir que una sesión se cree fuera 
 *            de las fechas de inicio y fin del curso.
 * Requisitos mínimos: 
 *  • Debe consultar app.cursos usando NEW.curso_id. 
 *  • Debe lanzar RAISE EXCEPTION si NEW.fecha_sesion es anterior a fecha_inicio 
 *    o posterior a fecha_fin. 
 *  • El trigger debe ser BEFORE INSERT OR UPDATE ON app.sesiones.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger que realiza la validación
CREATE OR REPLACE FUNCTION app.ej_trg_validar_fecha_sesion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
	v_fecha_inicio DATE;
	v_fecha_fin DATE;
BEGIN
	-- Consultamos el rango de fechas del curso asociado a la sesión entrante
	SELECT fecha_inicio, fecha_fin
	INTO v_fecha_inicio, v_fecha_fin
	FROM app.cursos
	WHERE curso_id = NEW.curso_id;

	-- Verificamos si la fecha de la sesión está fuera del rango permitido
	IF NEW.fecha_sesion < v_fecha_inicio THEN
		RAISE EXCEPTION 'Error: La fecha de la sesión (%) no puede ser anterior a la fecha de inicio del curso (%)', 
			NEW.fecha_sesion, v_fecha_inicio;
			
	ELSIF NEW.fecha_sesion > v_fecha_fin THEN
		RAISE EXCEPTION 'Error: La fecha de la sesión (%) no puede ser posterior a la fecha de fin del curso (%)', 
			NEW.fecha_sesion, v_fecha_fin;
	END IF;

	-- Si pasa las validaciones, permitimos que se guarde el registro original sin cambios
	RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado a la tabla app.sesiones
CREATE OR REPLACE TRIGGER ej_validar_fecha_sesion
BEFORE INSERT OR UPDATE ON app.sesiones
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_validar_fecha_sesion();

/*******************************************************************************
 * Normalizar la prioridad de las incidencias
 * Tipo: Función de trigger + trigger
 * Objetivo: Corregir automáticamente la prioridad antes de guardar una incidencia.
 * Crear la función app.ej_trg_normalizar_prioridad_incidencia() y el 
 *            trigger ej_normalizar_prioridad_incidencia para que la prioridad 
 *            de app.incidencias se guarde siempre en minúsculas y sin espacios.
 * Requisitos mínimos: 
 *  • La función debe devolver TRIGGER. 
 *  • Debe aplicar lower(btrim(NEW.prioridad)). 
 *  • El trigger debe ser BEFORE INSERT OR UPDATE OF prioridad ON app.incidencias. 
 *  • Debe devolver NEW.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger que normaliza el texto
CREATE OR REPLACE FUNCTION app.ej_trg_normalizar_prioridad_incidencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	-- Corregido: Aplicamos lower y btrim al campo prioridad entrante
	NEW.prioridad := LOWER(BTRIM(NEW.prioridad));

	-- Requisito mínimo: Debe devolver NEW
	RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado a la columna prioridad
CREATE OR REPLACE TRIGGER ej_normalizar_prioridad_incidencia
BEFORE INSERT OR UPDATE OF prioridad ON app.incidencias
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_normalizar_prioridad_incidencia();

/*******************************************************************************
 * Asignar fecha límite automática a tareas urgentes
 * Tipo: Función de trigger + trigger
 * Objetivo: Completar automáticamente un campo cuando el usuario no lo informa.
 * Crear la función app.ej_trg_fecha_limite_tarea_urgente() y el 
 *            trigger ej_fecha_limite_tarea_urgente para asignar fecha_limite 
 *            si se crea una tarea alta o crítica sin fecha límite.
 * Requisitos mínimos: 
 *  • Si NEW.fecha_limite ya tiene valor, no debe cambiarse. 
 *  • Si prioridad es critica y no hay fecha_limite, debe poner CURRENT_DATE. 
 *  • Si prioridad es alta y no hay fecha_limite, debe poner CURRENT_DATE + 2. 
 *  • El trigger debe ser BEFORE INSERT OR UPDATE OF prioridad, fecha_limite 
 *    ON app.tareas_pendientes.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger
CREATE OR REPLACE FUNCTION app.ej_trg_fecha_limite_tarea_urgente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	-- REGLA 1: Si NEW.fecha_limite YA tiene valor, no hacemos nada (respetamos el valor)
	IF NEW.fecha_limite IS NULL THEN
		
		-- REGLA 2: Si prioridad es critica y está vacía la fecha, ponemos la de hoy
		IF NEW.prioridad = 'critica' THEN
			NEW.fecha_limite := CURRENT_DATE;
			
		-- REGLA 3: Si prioridad es alta y está vacía la fecha, ponemos hoy + 2 días
		ELSIF NEW.prioridad = 'alta' THEN
			NEW.fecha_limite := CURRENT_DATE + 2;
		END IF;

	END IF;

	-- Retornamos NEW con los campos modificados (si aplica) para proceder al guardado
	RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado a las columnas específicas
CREATE OR REPLACE TRIGGER ej_fecha_limite_tarea_urgente
BEFORE INSERT OR UPDATE OF prioridad, fecha_limite ON app.tareas_pendientes
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_fecha_limite_tarea_urgente();

/*******************************************************************************
 * Pasar una incidencia abierta a revisión al cambiar su descripción
 * Tipo: Función de trigger + trigger
 * Objetivo: Modificar automáticamente el estado de una incidencia cuando se 
 *            actualiza información relevante.
 * Crear la función app.ej_trg_revision_por_cambio_descripcion() y el 
 *            trigger ej_revision_por_cambio_descripcion para que, si una 
 *            incidencia abierta cambia de descripción, su estado pase 
 *            automáticamente a en_revision.
 * Requisitos mínimos: 
 *  • Debe comparar OLD.descripcion y NEW.descripcion con IS DISTINCT FROM. 
 *  • Solo debe cambiar el estado si OLD.estado es 'abierta'. 
 *  • El trigger debe ser BEFORE UPDATE OF descripcion ON app.incidencias. 
 *  • Debe devolver NEW.
 *******************************************************************************/

-- PASO 1: Crear la función del trigger
CREATE OR REPLACE FUNCTION app.ej_trg_revision_por_cambio_descripcion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	-- REGLA 1: Comprobamos si el estado original de la incidencia era 'abierta'
	IF OLD.estado = 'abierta' THEN
		
		-- REGLA 2: Verificamos de forma segura si la descripción ha cambiado
		IF OLD.descripcion IS DISTINCT FROM NEW.descripcion THEN
			-- Modificamos automáticamente el estado del registro a 'en_revision'
			NEW.estado := 'en_revision';
		END IF;

	END IF;

	-- Requisito mínimo: Retornamos NEW para aplicar los cambios en la base de datos
	RETURN NEW;
END;
$$;

-- PASO 2: Crear el trigger asociado exclusivamente a la columna 'descripcion'
CREATE OR REPLACE TRIGGER ej_revision_por_cambio_descripcion
BEFORE UPDATE OF descripcion ON app.incidencias
FOR EACH ROW
EXECUTE FUNCTION app.ej_trg_revision_por_cambio_descripcion();

