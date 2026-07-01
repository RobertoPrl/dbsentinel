-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 04_triggers_negocio.sql
-- Finalidad: Reglas y automatizaciones de negocio para matrículas y cobros
-- ============================================================================

-- ============================================================================
-- 1. CONTROL ACADÉMICO AUTOMATIZADO (Identificadores y Disponibilidad de Aforo)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_generar_codigo_matricula()
-- ------------------------------------------------------------
-- Finalidad:
-- Generar automáticamente un código de matrícula si no se ha indicado.
--
-- Tipo de trigger previsto:
-- BEFORE INSERT ON app.matriculas.
--
-- Formato generado:
-- MAT-AAAA-CODIGO
-- Ejemplo: MAT-2026-A1B2C3D4
--
-- pgcrypto:
-- Se utiliza gen_random_bytes() para crear una parte aleatoria.
--
CREATE OR REPLACE FUNCTION app.trg_generar_codigo_matricula()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo genera código si el campo está a NULL o vacío.
    -- Si el usuario ya ha indicado un código, lo respeta.
    IF NEW.codigo_matricula IS NULL OR btrim(NEW.codigo_matricula) = '' THEN
        -- to_char(now(), 'YYYY') obtiene el año actual y gen_random_bytes genera la entropía hexadecimal.
        NEW.codigo_matricula := 'MAT-' || to_char(now(), 'YYYY') || '-' ||
                                upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));
    END IF;

    -- Devuelve la fila con el código de matrícula ya generado.
    RETURN NEW;
END;
$$;

CREATE TRIGGER generar_codigo_matricula
BEFORE INSERT ON app.matriculas
FOR EACH ROW
EXECUTE FUNCTION app.trg_generar_codigo_matricula();


-- ------------------------------------------------------------
-- Función de trigger: app.trg_control_plazas_matricula()
-- ------------------------------------------------------------
-- Finalidad:
-- Mantener actualizado el contador de plazas ocupadas de cada curso
-- según las matrículas que se crean, anulan, finalizan, reactivan o eliminan.
--
-- Tipo de trigger previsto:
-- AFTER INSERT OR UPDATE OF estado OR DELETE ON app.matriculas.
--
-- Por qué es AFTER:
-- Porque primero se aplica el cambio en la matrícula y después se actualiza
-- el contador del curso relacionado.
--
-- TG_OP:
-- Variable especial de PostgreSQL que indica qué operación disparó el trigger:
-- INSERT, UPDATE o DELETE.
--
-- SELECT ... FOR UPDATE:
-- Bloquea la fila del curso mientras se comprueban las plazas.
-- Esto evita que dos transacciones ocupen simultáneamente la última plaza.
--
CREATE OR REPLACE FUNCTION app.trg_control_plazas_matricula()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    -- Guardan temporalmente los datos de plazas del curso afectado.
    v_plazas_totales INTEGER;
    v_plazas_ocupadas INTEGER;
BEGIN
    -- Caso 1: se inserta una nueva matrícula.
    IF TG_OP = 'INSERT' THEN
        -- Solo ocupan plaza las matrículas pendientes de pago o activas.
        IF NEW.estado IN ('pendiente_pago','activa') THEN
            -- Se leen las plazas del curso y se bloquea la fila para evitar problemas de concurrencia.
            SELECT plazas_totales, plazas_ocupadas
            INTO v_plazas_totales, v_plazas_ocupadas
            FROM app.cursos
            WHERE curso_id = NEW.curso_id
            FOR UPDATE;

            -- Si ya no quedan plazas, se cancela la inserción.
            IF v_plazas_ocupadas >= v_plazas_totales THEN
                RAISE EXCEPTION 'No quedan plazas disponibles para el curso %', NEW.curso_id;
            END IF;

            -- Si hay plazas, se suma una plaza ocupada al curso.
            UPDATE app.cursos
            SET plazas_ocupadas = plazas_ocupadas + 1
            WHERE curso_id = NEW.curso_id;
        END IF;

        RETURN NEW;
    END IF;
 -- Caso 2: cambia el estado de una matrícula.
    IF TG_OP = 'UPDATE' THEN
        -- Si una matrícula que ocupaba plaza pasa a anulada o finalizada, se libera una plaza.
        IF OLD.estado IN ('pendiente_pago','activa') AND NEW.estado IN ('anulada','finalizada') THEN
            UPDATE app.cursos
            SET plazas_ocupadas = plazas_ocupadas - 1
            WHERE curso_id = OLD.curso_id;
        END IF;

        -- Si una matrícula que no ocupaba plaza vuelve a pendiente o activa, vuelve a ocupar plaza.
        IF OLD.estado IN ('anulada','finalizada') AND NEW.estado IN ('pendiente_pago','activa') THEN
            SELECT plazas_totales, plazas_ocupadas
            INTO v_plazas_totales, v_plazas_ocupadas
            FROM app.cursos
            WHERE curso_id = NEW.curso_id
            FOR UPDATE;

            -- Se comprueba de nuevo si hay plazas libres.
            IF v_plazas_ocupadas >= v_plazas_totales THEN
                RAISE EXCEPTION 'No quedan plazas disponibles para reactivar la matrícula';
            END IF;

            -- Se incrementa el número de plazas ocupadas.
            UPDATE app.cursos
            SET plazas_ocupadas = plazas_ocupadas + 1
            WHERE curso_id = NEW.curso_id;
        END IF;

        RETURN NEW;
    END IF;

    -- Caso 3: se elimina una matrícula.
    IF TG_OP = 'DELETE' THEN
        -- Si la matrícula eliminada ocupaba plaza, se resta una plaza ocupada.
        IF OLD.estado IN ('pendiente_pago','activa') THEN
            UPDATE app.cursos
            SET plazas_ocupadas = plazas_ocupadas - 1
            WHERE curso_id = OLD.curso_id;
        END IF;

        -- En DELETE no existe NEW. Por eso se devuelve OLD.
        RETURN OLD;
    END IF;

    -- Seguridad: si llegara una operación no contemplada, no devuelve fila.
    RETURN NULL;
END;
$$;

CREATE TRIGGER control_plazas_matricula
AFTER INSERT OR UPDATE OF estado OR DELETE ON app.matriculas
FOR EACH ROW
EXECUTE FUNCTION app.trg_control_plazas_matricula();


-- ============================================================================
-- 2. GESTIÓN MONETARIA Y ESCALADO OPERATIVO (Flujos Financieros e Incidencias)
-- ============================================================================

-- ------------------------------------------------------------
-- Función de trigger: app.trg_actualizar_pago_matricula()
-- ------------------------------------------------------------
-- Finalidad:
-- Actualizar automáticamente el importe pagado de una matrícula
-- cuando se inserta o elimina un pago.
--
-- Tipo de trigger previsto:
-- AFTER INSERT OR DELETE ON app.pagos.
--
-- Reglas de negocio:
-- 1. Al insertar un pago, se suma al importe_pagado de la matrícula.
-- 2. Si el importe pagado supera el total, se cancela la operación.
-- 3. Si la matrícula queda completamente pagada, pasa a estado activa.
-- 4. Si se elimina un pago, se descuenta del importe_pagado.
--
CREATE OR REPLACE FUNCTION app.trg_actualizar_pago_matricula()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    -- v_total almacena el importe total de la matrícula.
    v_total NUMERIC(10,2);
    -- v_pagado almacena el nuevo importe pagado tras aplicar el pago.
    v_pagado NUMERIC(10,2);
BEGIN
    -- Caso 1: se inserta un nuevo pago.
    IF TG_OP = 'INSERT' THEN
        -- Suma el importe del pago al importe ya pagado de la matrícula.
        -- RETURNING permite recuperar los valores actualizados en variables locales.
        UPDATE app.matriculas
        SET importe_pagado = importe_pagado + NEW.importe
        WHERE matricula_id = NEW.matricula_id
        RETURNING importe_total, importe_pagado INTO v_total, v_pagado;

        -- Si el pago acumulado supera el importe total, se cancela la operación.
        IF v_pagado > v_total THEN
            RAISE EXCEPTION 'El pago supera el importe total de la matrícula. Total: %, pagado: %', v_total, v_pagado;
        END IF;

        -- Si la matrícula queda totalmente pagada, se activa automáticamente.
        IF v_pagado = v_total THEN
            UPDATE app.matriculas
            SET estado = 'activa'
            WHERE matricula_id = NEW.matricula_id AND estado = 'pendiente_pago';
        END IF;

        RETURN NEW;
    END IF;

    -- Caso 2: se elimina un pago.
    IF TG_OP = 'DELETE' THEN
        -- Se resta el importe del pago eliminado y se reevalúa el estado remanente.
        UPDATE app.matriculas
        SET importe_pagado = importe_pagado - OLD.importe,
            estado = CASE
                WHEN importe_pagado - OLD.importe < importe_total THEN 'pendiente_pago'
                ELSE estado
            END
        WHERE matricula_id = OLD.matricula_id;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER actualizar_pago_matricula
AFTER INSERT OR DELETE ON app.pagos
FOR EACH ROW
EXECUTE FUNCTION app.trg_actualizar_pago_matricula();


-- ------------------------------------------------------------
-- Función de trigger: app.trg_tarea_desde_incidencia()
-- ------------------------------------------------------------
-- Finalidad:
-- Crear automáticamente una tarea pendiente cuando se registra una
-- incidencia de prioridad alta o crítica.
--
-- Tipo de trigger previsto:
-- AFTER INSERT ON app.incidencias.
--
-- Regla de negocio:
-- - Incidencia crítica: tarea con fecha límite hoy.
-- - Incidencia alta: tarea con fecha límite dentro de 2 días.
-- - Incidencias baja o media: no generan tarea automática.
--
CREATE OR REPLACE FUNCTION app.trg_tarea_desde_incidencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo se genera tarea para incidencias importantes.
    IF NEW.prioridad IN ('alta','critica') THEN
        INSERT INTO app.tareas_pendientes (
            origen, origen_id, titulo, descripcion, prioridad, fecha_limite
        ) VALUES (
            'incidencia',
            NEW.incidencia_id,
            'Revisar incidencia ' || NEW.tipo,
            NEW.descripcion,
            NEW.prioridad,
            CASE
                WHEN NEW.prioridad = 'critica' THEN CURRENT_DATE
                ELSE CURRENT_DATE + 2
            END
        );
    END IF;

    -- Se devuelve NEW porque el trigger se ejecuta tras insertar la incidencia.
    RETURN NEW;
END;
$$;

CREATE TRIGGER tarea_desde_incidencia
AFTER INSERT ON app.incidencias
FOR EACH ROW
EXECUTE FUNCTION app.trg_tarea_desde_incidencia();