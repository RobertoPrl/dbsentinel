-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 06_procedimientos.sql
-- Finalidad: Procedimientos almacenados para la gestión académica y del negocio
-- ============================================================================

-- ============================================================================
-- 1. OPERACIONES EN TIEMPO REAL (Flujos de Matriculación y Caja)
-- ============================================================================

-- ------------------------------------------------------------
-- Procedimiento: app.matricular_alumno(...)
-- ------------------------------------------------------------
-- Finalidad:
-- Dar de alta una matrícula completa en una sola llamada.
--
-- Qué hace:
-- 1. Busca si el alumno ya existe por DNI.
-- 2. Si no existe, lo crea.
-- 3. Si existe, actualiza sus datos básicos.
-- 4. Busca el curso por código, pero solo si está abierto.
-- 5. Crea la matrícula.
--
-- Automatizaciones relacionadas:
-- - El trigger generar_codigo_matricula crea el código de matrícula.
-- - El trigger control_plazas_matricula comprueba y actualiza plazas.
-- - El trigger normalizar_email_alumno limpia el email del alumno.
--
CREATE OR REPLACE PROCEDURE app.matricular_alumno(
    p_dni VARCHAR,
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_email VARCHAR,
    p_telefono VARCHAR,
    p_codigo_curso VARCHAR,
    p_importe_total NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Identificador del alumno encontrado o creado.
    v_alumno_id BIGINT;
    -- Identificador del curso abierto encontrado.
    v_curso_id BIGINT;
BEGIN
    -- 1. Buscar si ya existe un alumno con el DNI recibido.
    SELECT alumno_id INTO v_alumno_id
    FROM app.alumnos
    WHERE dni = p_dni;

    -- Si no existe el alumno, se crea uno nuevo.
    IF v_alumno_id IS NULL THEN
        INSERT INTO app.alumnos (dni, nombre, apellidos, email, telefono)
        VALUES (p_dni, p_nombre, p_apellidos, p_email, p_telefono)
        RETURNING alumno_id INTO v_alumno_id;
    ELSE
        -- Si el alumno ya existe, se actualizan sus datos.
        UPDATE app.alumnos
        SET nombre = p_nombre,
            apellidos = p_apellidos,
            email = p_email,
            telefono = p_telefono
        WHERE alumno_id = v_alumno_id;
    END IF;

    -- 2. Localizar el curso por código, asegurando que está abierto.
    SELECT curso_id INTO v_curso_id
    FROM app.cursos
    WHERE codigo = p_codigo_curso
      AND estado = 'abierto';

    -- Si no existe curso abierto con ese código, se cancela el procedimiento.
    IF v_curso_id IS NULL THEN
        RAISE EXCEPTION 'No existe un curso abierto con código %', p_codigo_curso;
    END IF;

    -- 3. Crear la matrícula.
    INSERT INTO app.matriculas (alumno_id, curso_id, importe_total)
    VALUES (v_alumno_id, v_curso_id, p_importe_total);
END;
$$;

-- Ejemplo de ejecución manual para pruebas:
-- CALL app.matricular_alumno('44444444D', 'Carlos', 'Pérez Mora', 'carlos.perez@example.com', '600777888', 'SQL-AUD-01', 250.00);


-- ------------------------------------------------------------
-- Procedimiento: app.registrar_pago_matricula(...)
-- ------------------------------------------------------------
-- Finalidad:
-- Registrar un pago usando el código de matrícula en lugar del ID interno.
--
-- Qué hace:
-- 1. Busca la matrícula por su código.
-- 2. Calcula la deuda pendiente.
-- 3. Valida que el importe sea positivo.
-- 4. Valida que el pago no supere la deuda.
-- 5. Inserta el pago en app.pagos.
--
-- Automatización relacionada:
-- El trigger actualizar_pago_matricula actualiza importe_pagado y,
-- si procede, cambia el estado de la matrícula a activa.
--
CREATE OR REPLACE PROCEDURE app.registrar_pago_matricula(
    p_codigo_matricula VARCHAR,
    p_importe NUMERIC,
    p_metodo VARCHAR,
    p_referencia VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ID interno de la matrícula encontrada.
    v_matricula_id BIGINT;
    -- Importe pendiente de pago.
    v_deuda NUMERIC(10,2);
BEGIN
    -- Se busca la matrícula y se calcula la deuda pendiente.
    SELECT matricula_id, importe_total - importe_pagado
    INTO v_matricula_id, v_deuda
    FROM app.matriculas
    WHERE codigo_matricula = p_codigo_matricula;

    -- Si no existe la matrícula, se cancela.
    IF v_matricula_id IS NULL THEN
        RAISE EXCEPTION 'No existe matrícula con código %', p_codigo_matricula;
    END IF;

    -- No se permiten pagos negativos ni pagos de importe cero.
    IF p_importe <= 0 THEN
        RAISE EXCEPTION 'El importe debe ser positivo';
    END IF;

    -- No se permite pagar más de lo que falta.
    IF p_importe > v_deuda THEN
        RAISE EXCEPTION 'El importe % supera la deuda pendiente %', p_importe, v_deuda;
    END IF;

    -- Se inserta el pago. El trigger asociado se encarga de actualizar la matrícula.
    INSERT INTO app.pagos (matricula_id, importe, metodo, referencia)
    VALUES (v_matricula_id, p_importe, p_metodo, p_referencia);
END;
$$;

-- Ejemplo de ejecución manual para pruebas:
-- CALL app.registrar_pago_matricula('MAT-2026-XXXXXXXX', 100, 'transferencia', 'BANCO-003');

-- ============================================================================
-- 2. TAREAS PROGRAMADAS Y PROCESOS PERIÓDICOS (Generación de Calendarios y Alertas)
-- ============================================================================

-- ------------------------------------------------------------
-- Procedimiento: app.generar_sesiones_curso(...)
-- ------------------------------------------------------------
-- Finalidad:
-- Crear automáticamente las sesiones de un curso para un día fijo
-- de la semana dentro del rango de fechas del curso.
--
-- Parámetros:
-- p_codigo_curso: código del curso.
-- p_dia_semana: número de día ISO. 1 lunes, 2 martes, ..., 7 domingo.
-- p_hora_inicio: hora de inicio de cada sesión.
-- p_hora_fin: hora de fin de cada sesión.
-- p_aula: aula donde se imparte.
--
-- ON CONFLICT DO NOTHING:
-- Evita error si una sesión ya existe para ese curso, fecha y hora.
--
CREATE OR REPLACE PROCEDURE app.generar_sesiones_curso(
    p_codigo_curso VARCHAR,
    p_dia_semana INTEGER,
    p_hora_inicio TIME,
    p_hora_fin TIME,
    p_aula VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ID del curso localizado.
    v_curso_id BIGINT;
    -- Fechas de inicio y fin del curso.
    v_inicio DATE;
    v_fin DATE;
    -- Fecha que se va recorriendo dentro del bucle.
    v_fecha DATE;
BEGIN
    -- Validar que el día de la semana sea correcto.
    IF p_dia_semana NOT BETWEEN 1 AND 7 THEN
        RAISE EXCEPTION 'El día de la semana debe estar entre 1 y 7';
    END IF;

    -- Buscar el curso por su código.
    SELECT curso_id, fecha_inicio, fecha_fin
    INTO v_curso_id, v_inicio, v_fin
    FROM app.cursos
    WHERE codigo = p_codigo_curso;

    -- Si no existe, se cancela.
    IF v_curso_id IS NULL THEN
        RAISE EXCEPTION 'No existe el curso %', p_codigo_curso;
    END IF;

    -- Empezamos a recorrer fechas desde la fecha inicial del curso.
    v_fecha := v_inicio;

    -- Recorre todos los días desde el inicio hasta el fin del curso.
    WHILE v_fecha <= v_fin LOOP
        -- Se comprueba si el día de la semana coincide con el solicitado.
        IF EXTRACT(ISODOW FROM v_fecha) = p_dia_semana THEN
            -- Inserta una sesión para esa fecha. Si ya existe, no hace nada.
            INSERT INTO app.sesiones (curso_id, fecha_sesion, hora_inicio, hora_fin, aula)
            VALUES (v_curso_id, v_fecha, p_hora_inicio, p_hora_fin, p_aula)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Avanza al día siguiente.
        v_fecha := v_fecha + 1;
    END LOOP;
END;
$$;

-- Ejemplo de ejecución manual para pruebas:
-- CALL app.generar_sesiones_curso('SQL-AUD-01', 1, '18:00', '20:00', 'Aula 2');


-- ------------------------------------------------------------
-- Procedimiento: app.generar_tareas_pagos_pendientes()
-- ------------------------------------------------------------
-- Finalidad:
-- Crear tareas de seguimiento para matrículas que tienen pagos pendientes.
--
-- Por qué es procedimiento y no trigger:
-- Porque no depende de un único INSERT o UPDATE concreto. Es una revisión
-- periódica que podría ejecutarse una vez al día mediante pgAgent, cron,
-- Programador de tareas o manualmente.
--
-- Regla:
-- - Si la matrícula pendiente tiene más de 15 días, la tarea será alta.
-- - En caso contrario, será media.
-- - No duplica tareas si ya existe una pendiente o en proceso.
--
CREATE OR REPLACE PROCEDURE app.generar_tareas_pagos_pendientes()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Inserta tareas para las matrículas que cumplen las condiciones.
    INSERT INTO app.tareas_pendientes (
        origen, origen_id, titulo, descripcion, prioridad, fecha_limite
    )
    SELECT
        'matricula',
        m.matricula_id,
        'Revisar pago pendiente',
        'La matrícula ' || m.codigo_matricula || ' tiene deuda pendiente de ' || (m.importe_total - m.importe_pagado) || ' euros.',
        CASE
            WHEN CURRENT_DATE - m.fecha_matricula > 15 THEN 'alta'
            ELSE 'media'
        END,
        CURRENT_DATE + 3
    FROM app.matriculas m
    WHERE m.estado = 'pendiente_pago'
      AND m.importe_pagado < m.importe_total
      -- Evita crear tareas duplicadas para la misma matrícula.
      AND NOT EXISTS (
          SELECT 1
          FROM app.tareas_pendientes t
          WHERE t.origen = 'matricula'
            AND t.origen_id = m.matricula_id
            AND t.estado IN ('pendiente','en_proceso')
      );
END;
$$;

-- Prueba de la rutina y verificación del resultado:
-- CALL app.generar_tareas_pagos_pendientes();
-- SELECT * FROM app.tareas_pendientes ORDER BY creado_en DESC;


-- ------------------------------------------------------------
-- Procedimiento: app.cerrar_curso(p_codigo)
-- ------------------------------------------------------------
-- Finalidad:
-- Cerrar un curso y finalizar sus matrículas activas.
--
-- Qué hace:
-- 1. Busca el curso por su código.
-- 2. Si no existe, muestra error.
-- 3. Cambia a finalizada las matrículas activas de ese curso.
-- 4. Cambia el estado del curso a finalizado.
--
-- Observación:
-- Este procedimiento agrupa una operación administrativa completa.
--
CREATE OR REPLACE PROCEDURE app.cerrar_curso(p_codigo VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ID interno del curso que se va a cerrar.
    v_curso_id BIGINT;
BEGIN
    -- Buscar el curso por código.
    SELECT curso_id INTO v_curso_id
    FROM app.cursos
    WHERE codigo = p_codigo;

    -- Si no existe, cancelar la operación.
    IF v_curso_id IS NULL THEN
        RAISE EXCEPTION 'No existe el curso %', p_codigo;
    END IF;

    -- Finalizar solo las matrículas activas de ese curso.
    UPDATE app.matriculas
    SET estado = 'finalizada'
    WHERE curso_id = v_curso_id
      AND estado = 'activa';

    -- Marcar el curso como finalizado.
    UPDATE app.cursos
    SET estado = 'finalizado'
    WHERE curso_id = v_curso_id;
END;
$$;

-- Ejemplo de ejecución manual para pruebas:
-- CALL app.cerrar_curso('SQL-AUD-01');
