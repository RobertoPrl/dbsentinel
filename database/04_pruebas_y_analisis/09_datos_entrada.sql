-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 09_datos_entrada.sql
-- Finalidad: Carga masiva de datos iniciales para pruebas del sistema
-- ============================================================================

-- ============================================================================
-- 0. LIMPIEZA PREVIA (Reinicio Opcional de Tablas)
-- ============================================================================

-- [Comentario Extra]: Vaciado total con reinicio de contadores ID en cascada
TRUNCATE TABLE
    app.tareas_pendientes,
    app.incidencias,
    app.asistencia,
    app.sesiones,
    app.pagos,
    app.matriculas,
    app.cursos,
    app.alumnos
RESTART IDENTITY CASCADE;


-- ============================================================================
-- 1. REGISTRO DE ALUMNOS (Datos Demográficos de Prueba)
-- ============================================================================

INSERT INTO app.alumnos
(dni, nombre, apellidos, email, telefono, activo, creado_en, actualizado_en)
VALUES
('10000001A', 'Laura', 'Martínez Sánchez', 'laura.martinez@example.com', '600100001', TRUE, now(), now()),
('10000002B', 'Carlos', 'García López', 'carlos.garcia@example.com', '600100002', TRUE, now(), now()),
('10000003C', 'Marta', 'Soler Ruiz', 'marta.soler@example.com', '600100003', TRUE, now(), now()),
('10000004D', 'David', 'Fernández Torres', 'david.fernandez@example.com', '600100004', TRUE, now(), now()),
('10000005E', 'Ana', 'Romero Gil', 'ana.romero@example.com', '600100005', TRUE, now(), now()),
('10000006F', 'Javier', 'Navarro Pérez', 'javier.navarro@example.com', '600100006', TRUE, now(), now()),
('10000007G', 'Sara', 'Vidal Moreno', 'sara.vidal@example.com', '600100007', TRUE, now(), now()),
('10000008H', 'Pablo', 'Castro Medina', 'pablo.castro@example.com', '600100008', TRUE, now(), now()),
('10000009J', 'Elena', 'Ortega Ramos', 'elena.ortega@example.com', '600100009', TRUE, now(), now()),
('10000010K', 'Miguel', 'Herrera Molina', 'miguel.herrera@example.com', '600100010', TRUE, now(), now()),
('10000011L', 'Nuria', 'Iglesias Vega', 'nuria.iglesias@example.com', '600100011', TRUE, now(), now()),
('10000012M', 'Óscar', 'Santos León', 'oscar.santos@example.com', '600100012', TRUE, now(), now()),
('10000013N', 'Lucía', 'Reyes Cano', 'lucia.reyes@example.com', '600100013', TRUE, now(), now()),
('10000014P', 'Daniel', 'Méndez Cruz', 'daniel.mendez@example.com', '600100014', TRUE, now(), now()),
('10000015Q', 'Paula', 'Campos Ferrer', 'paula.campos@example.com', '600100015', TRUE, now(), now()),
('10000016R', 'Alberto', 'Rivas Romero', 'alberto.rivas@example.com', '600100016', TRUE, now(), now()),
('10000017S', 'Cristina', 'Benítez Marín', 'cristina.benitez@example.com', '600100017', TRUE, now(), now()),
('10000018T', 'Raúl', 'Pascual Lozano', 'raul.pascual@example.com', '600100018', TRUE, now(), now()),
('10000019V', 'Irene', 'Fuentes Arias', 'irene.fuentes@example.com', '600100019', TRUE, now(), now()),
('10000020W', 'Sergio', 'Molina Serrano', 'sergio.molina@example.com', '600100020', TRUE, now(), now()),
('10000021X', 'Beatriz', 'Núñez Gallego', 'beatriz.nunez@example.com', '600100021', TRUE, now(), now()),
('10000022Y', 'Rubén', 'Pardo Aguilar', 'ruben.pardo@example.com', '600100022', TRUE, now(), now()),
('10000023Z', 'Clara', 'Domínguez Prieto', 'clara.dominguez@example.com', '600100023', TRUE, now(), now()),
('10000024A', 'Adrián', 'Serrano Blanco', 'adrian.serrano@example.com', '600100024', TRUE, now(), now()),
('10000025B', 'Marina', 'Cortés Martín', 'marina.cortes@example.com', '600100025', TRUE, now(), now()),
('10000026C', 'Hugo', 'Peña Suárez', 'hugo.pena@example.com', '600100026', TRUE, now(), now()),
('10000027D', 'Alicia', 'Lorenzo Pastor', 'alicia.lorenzo@example.com', '600100027', TRUE, now(), now()),
('10000028E', 'Iván', 'Rojas Delgado', 'ivan.rojas@example.com', '600100028', TRUE, now(), now()),
('10000029F', 'Carmen', 'Vargas Roldán', 'carmen.vargas@example.com', '600100029', TRUE, now(), now()),
('10000030G', 'Jorge', 'Calvo Esteban', 'jorge.calvo@example.com', '600100030', FALSE, now(), now());


-- ============================================================================
-- 2. REGISTRO DE CURSOS (Oferta Formativa Temporal)
-- ============================================================================

INSERT INTO app.cursos
(codigo, titulo, fecha_inicio, fecha_fin, plazas_totales, plazas_ocupadas, estado, creado_en, actualizado_en)
VALUES
('IFCT0101', 'Introducción a PostgreSQL', '2026-02-02', '2026-03-06', 20, 0, 'finalizado', now(), now()),
('IFCT0102', 'Administración de bases de datos PostgreSQL', '2026-03-09', '2026-04-17', 18, 0, 'finalizado', now(), now()),
('IFCT0103', 'MongoDB para administración de datos', '2026-04-20', '2026-05-22', 16, 0, 'finalizado', now(), now()),
('IFCT0104', 'Seguridad y usuarios en SGBD', '2026-06-01', '2026-07-10', 18, 0, 'en_curso', now(), now()),
('IFCT0105', 'Copias de seguridad y recuperación', '2026-07-13', '2026-08-07', 15, 0, 'abierto', now(), now()),
('IFCT0106', 'Monitorización y rendimiento de SGBD', '2026-09-01', '2026-10-09', 20, 0, 'planificado', now(), now()),
('IFCT0107', 'SQL avanzado para análisis de datos', '2026-10-13', '2026-11-20', 20, 0, 'planificado', now(), now()),
('IFCT0108', 'Proyecto final de administración de SGBD', '2026-11-23', '2026-12-18', 12, 0, 'planificado', now(), now());

-- ============================================================================
-- 3. INSCRIPCIÓN DE MATRÍCULAS (Asociación Alumnos - Cursos mediante CTE)
-- ============================================================================

WITH datos_matricula (codigo_matricula, dni, codigo_curso, fecha_matricula, estado, importe_total, importe_pagado) AS (
    VALUES
    ('MAT-2026-0001', '10000001A', 'IFCT0101', '2026-01-20'::date, 'finalizada', 420.00, 420.00),
    ('MAT-2026-0002', '10000002B', 'IFCT0101', '2026-01-21'::date, 'finalizada', 420.00, 420.00),
    ('MAT-2026-0003', '10000003C', 'IFCT0101', '2026-01-22'::date, 'finalizada', 420.00, 420.00),
    ('MAT-2026-0004', '10000004D', 'IFCT0101', '2026-01-23'::date, 'finalizada', 420.00, 420.00),
    ('MAT-2026-0005', '10000005E', 'IFCT0101', '2026-01-24'::date, 'anulada', 420.00, 0.00),

    ('MAT-2026-0006', '10000006F', 'IFCT0102', '2026-02-15'::date, 'finalizada', 520.00, 520.00),
    ('MAT-2026-0007', '10000007G', 'IFCT0102', '2026-02-16'::date, 'finalizada', 520.00, 520.00),
    ('MAT-2026-0008', '10000008H', 'IFCT0102', '2026-02-17'::date, 'finalizada', 520.00, 520.00),
    ('MAT-2026-0009', '10000009J', 'IFCT0102', '2026-02-18'::date, 'finalizada', 520.00, 260.00),
    ('MAT-2026-0010', '10000010K', 'IFCT0102', '2026-02-19'::date, 'activa', 520.00, 520.00),

    ('MAT-2026-0011', '10000011L', 'IFCT0103', '2026-04-01'::date, 'finalizada', 480.00, 480.00),
    ('MAT-2026-0012', '10000012M', 'IFCT0103', '2026-04-02'::date, 'finalizada', 480.00, 480.00),
    ('MAT-2026-0013', '10000013N', 'IFCT0103', '2026-04-03'::date, 'finalizada', 480.00, 240.00),
    ('MAT-2026-0014', '10000014P', 'IFCT0103', '2026-04-04'::date, 'finalizada', 480.00, 480.00),
    ('MAT-2026-0015', '10000015Q', 'IFCT0103', '2026-04-05'::date, 'anulada', 480.00, 0.00),

    ('MAT-2026-0016', '10000016R', 'IFCT0104', '2026-05-20'::date, 'activa', 560.00, 560.00),
    ('MAT-2026-0017', '10000017S', 'IFCT0104', '2026-05-21'::date, 'activa', 560.00, 280.00),
    ('MAT-2026-0018', '10000018T', 'IFCT0104', '2026-05-22'::date, 'activa', 560.00, 560.00),
    ('MAT-2026-0019', '10000019V', 'IFCT0104', '2026-05-23'::date, 'pendiente_pago', 560.00, 0.00),
    ('MAT-2026-0020', '10000020W', 'IFCT0104', '2026-05-24'::date, 'activa', 560.00, 560.00),
    ('MAT-2026-0021', '10000021X', 'IFCT0104', '2026-05-25'::date, 'activa', 560.00, 560.00),

    ('MAT-2026-0022', '10000022Y', 'IFCT0105', '2026-06-20'::date, 'activa', 390.00, 390.00),
    ('MAT-2026-0023', '10000023Z', 'IFCT0105', '2026-06-21'::date, 'pendiente_pago', 390.00, 0.00),
    ('MAT-2026-0024', '10000024A', 'IFCT0105', '2026-06-22'::date, 'activa', 390.00, 195.00),
    ('MAT-2026-0025', '10000025B', 'IFCT0105', '2026-06-23'::date, 'activa', 390.00, 390.00),

    ('MAT-2026-0026', '10000026C', 'IFCT0106', '2026-08-10'::date, 'pendiente_pago', 600.00, 0.00),
    ('MAT-2026-0027', '10000027D', 'IFCT0106', '2026-08-11'::date, 'activa', 600.00, 300.00),
    ('MAT-2026-0028', '10000028E', 'IFCT0106', '2026-08-12'::date, 'activa', 600.00, 600.00),

    ('MAT-2026-0029', '10000029F', 'IFCT0107', '2026-09-05'::date, 'pendiente_pago', 450.00, 0.00),
    ('MAT-2026-0030', '10000030G', 'IFCT0108', '2026-10-01'::date, 'anulada', 300.00, 0.00)
)
INSERT INTO app.matriculas
(codigo_matricula, alumno_id, curso_id, fecha_matricula, estado, importe_total, importe_pagado, creado_en, actualizado_en)
SELECT
    dm.codigo_matricula,
    a.alumno_id,
    c.curso_id,
    dm.fecha_matricula,
    dm.estado,
    dm.importe_total,
    dm.importe_pagado,
    now(),
    now()
FROM datos_matricula dm
JOIN app.alumnos a ON a.dni = dm.dni
JOIN app.cursos c ON c.codigo = dm.codigo_curso;

-- Actualizar plazas ocupadas según matrículas activas, finalizadas o pendientes de pago.
UPDATE app.cursos c
SET plazas_ocupadas = sub.total,
    actualizado_en = now()
FROM (
    SELECT curso_id, COUNT(*)::integer AS total
    FROM app.matriculas
    WHERE estado IN ('pendiente_pago', 'activa', 'finalizada')
    GROUP BY curso_id
) sub
WHERE c.curso_id = sub.curso_id;


-- ============================================================================
-- 4. HISTORIAL DE RECAUDACIÓN (Simulación de Transacciones de Caja)
-- ============================================================================

WITH datos_pago (codigo_matricula, fecha_pago, importe, metodo, referencia) AS (
    VALUES
    ('MAT-2026-0001', '2026-01-20'::date, 420.00, 'tarjeta', 'TPV-0001'),
    ('MAT-2026-0002', '2026-01-21'::date, 420.00, 'transferencia', 'TRF-0002'),
    ('MAT-2026-0003', '2026-01-22'::date, 420.00, 'bizum', 'BIZ-0003'),
    ('MAT-2026-0004', '2026-01-23'::date, 420.00, 'efectivo', 'REC-0004'),

    ('MAT-2026-0006', '2026-02-15'::date, 520.00, 'tarjeta', 'TPV-0006'),
    ('MAT-2026-0007', '2026-02-16'::date, 520.00, 'transferencia', 'TRF-0007'),
    ('MAT-2026-0008', '2026-02-17'::date, 520.00, 'bizum', 'BIZ-0008'),
    ('MAT-2026-0009', '2026-02-18'::date, 260.00, 'tarjeta', 'TPV-0009-1'),
    ('MAT-2026-0010', '2026-02-19'::date, 520.00, 'tarjeta', 'TPV-0010'),

    ('MAT-2026-0011', '2026-04-01'::date, 480.00, 'transferencia', 'TRF-0011'),
    ('MAT-2026-0012', '2026-04-02'::date, 480.00, 'tarjeta', 'TPV-0012'),
    ('MAT-2026-0013', '2026-04-03'::date, 240.00, 'bizum', 'BIZ-0013-1'),
    ('MAT-2026-0014', '2026-04-04'::date, 480.00, 'efectivo', 'REC-0014'),

    ('MAT-2026-0016', '2026-05-20'::date, 560.00, 'tarjeta', 'TPV-0016'),
    ('MAT-2026-0017', '2026-05-21'::date, 280.00, 'transferencia', 'TRF-0017-1'),
    ('MAT-2026-0018', '2026-05-22'::date, 560.00, 'bizum', 'BIZ-0018'),
    ('MAT-2026-0020', '2026-05-24'::date, 560.00, 'tarjeta', 'TPV-0020'),
    ('MAT-2026-0021', '2026-05-25'::date, 560.00, 'tarjeta', 'TPV-0021'),

    ('MAT-2026-0022', '2026-06-20'::date, 390.00, 'transferencia', 'TRF-0022'),
    ('MAT-2026-0024', '2026-06-22'::date, 195.00, 'tarjeta', 'TPV-0024-1'),
    ('MAT-2026-0025', '2026-06-23'::date, 390.00, 'bizum', 'BIZ-0025'),

    ('MAT-2026-0027', '2026-08-11'::date, 300.00, 'transferencia', 'TRF-0027-1'),
    ('MAT-2026-0028', '2026-08-12'::date, 600.00, 'tarjeta', 'TPV-0028')
)
INSERT INTO app.pagos
(matricula_id, fecha_pago, importe, metodo, referencia, creado_en)
SELECT
    m.matricula_id,
    dp.fecha_pago,
    dp.importe,
    dp.metodo,
    dp.referencia,
    now()
FROM datos_pago dp
JOIN app.matriculas m ON m.codigo_matricula = dp.codigo_matricula;
-- ============================================================================
-- 5. PLANIFICACIÓN DE CLASES (Calendarios Semanales mediante Series)
-- ============================================================================

WITH cursos_base AS (
    SELECT curso_id, codigo, fecha_inicio
    FROM app.cursos
)
INSERT INTO app.sesiones
(curso_id, fecha_sesion, hora_inicio, hora_fin, aula, creado_en)
SELECT
    c.curso_id,
    c.fecha_inicio + ((gs.n - 1) * 7),
    CASE WHEN c.codigo IN ('IFCT0101','IFCT0102','IFCT0103') THEN '09:00'::time ELSE '16:00'::time END,
    CASE WHEN c.codigo IN ('IFCT0101','IFCT0102','IFCT0103') THEN '13:00'::time ELSE '20:00'::time END,
    CASE
        WHEN c.codigo IN ('IFCT0101','IFCT0102') THEN 'Aula 1'
        WHEN c.codigo IN ('IFCT0103','IFCT0104') THEN 'Aula 2'
        WHEN c.codigo IN ('IFCT0105','IFCT0106') THEN 'Aula 3'
        ELSE 'Aula Virtual'
    END,
    now()
FROM cursos_base c
CROSS JOIN generate_series(1, 6) AS gs(n);


-- ============================================================================
-- 6. CONTROL DE ASISTENCIA (Carga Semialeatoria Basada en Operadores Matemáticos)
-- ============================================================================

-- Actualizar asistencia para matrículas activas/finalizadas en sesiones de su curso. 
-- Se excluyen matrículas anuladas y pendientes de pago.
INSERT INTO app.asistencia
(sesion_id, matricula_id, estado, observaciones, creado_en, actualizado_en)
SELECT
    s.sesion_id,
    m.matricula_id,
    CASE
        WHEN (m.matricula_id + s.sesion_id) % 11 = 0 THEN 'ausente'
        WHEN (m.matricula_id + s.sesion_id) % 7 = 0 THEN 'justificada'
        ELSE 'presente'
    END AS estado,
    CASE
        WHEN (m.matricula_id + s.sesion_id) % 11 = 0 THEN 'No asiste a la sesión.'
        WHEN (m.matricula_id + s.sesion_id) % 7 = 0 THEN 'Ausencia justificada por el alumno.'
        ELSE NULL
    END AS observaciones,
    now(),
    now()
FROM app.sesiones s
JOIN app.matriculas m ON m.curso_id = s.curso_id
WHERE m.estado IN ('activa', 'finalizada');


-- ============================================================================
-- 7. REGISTRO DE INCIDENCIAS (Soporte Técnico y Administrativo)
-- ============================================================================

WITH datos_incidencia (codigo_matricula, tipo, prioridad, descripcion, estado) AS (
    VALUES
    ('MAT-2026-0009', 'pago', 'alta', 'Importe pendiente de completar en la matrícula.', 'abierta'),
    ('MAT-2026-0013', 'pago', 'media', 'El alumno solicita fraccionamiento del importe restante.', 'en_revision'),
    ('MAT-2026-0017', 'pago', 'media', 'Pago parcial registrado; queda pendiente el segundo plazo.', 'abierta'),
    ('MAT-2026-0019', 'administrativa', 'alta', 'Matrícula pendiente de pago antes del inicio de sesiones.', 'abierta'),
    ('MAT-2026-0023', 'administrativa', 'media', 'Documentación de matrícula incompleta.', 'en_revision'),
    ('MAT-2026-0024', 'pago', 'media', 'Pendiente de confirmar el segundo pago.', 'abierta'),
    ('MAT-2026-0027', 'pago', 'baja', 'Alumno solicita justificante del pago realizado.', 'resuelta'),
    ('MAT-2026-0001', 'academica', 'baja', 'Consulta sobre material adicional del curso.', 'cerrada'),
    ('MAT-2026-0016', 'asistencia', 'media', 'Revisión de una falta marcada como ausente.', 'en_revision'),
    ('MAT-2026-0028', 'academica', 'media', 'Solicitud de acceso anticipado a contenidos.', 'abierta')
)
INSERT INTO app.incidencias
(matricula_id, tipo, prioridad, descripcion, estado, creado_en, actualizado_en)
SELECT
    m.matricula_id,
    di.tipo,
    di.prioridad,
    di.descripcion,
    di.estado,
    now(),
    now()
FROM datos_incidencia di
JOIN app.matriculas m ON m.codigo_matricula = di.codigo_matricula;

-- Incidencia general sin matrícula asociada.
INSERT INTO app.incidencias
(matricula_id, tipo, prioridad, descripcion, estado, creado_en, actualizado_en)
VALUES
(NULL, 'administrativa', 'baja', 'Revisión general de datos de contacto de alumnos inactivos.', 'abierta', now(), now());


-- ============================================================================
-- 8. COLA DE TRABAJO INTERNA (Seguimiento Operativo Manual)
-- ============================================================================

INSERT INTO app.tareas_pendientes
(origen, origen_id, titulo, descripcion, prioridad, estado, fecha_limite, creado_en, actualizado_en)
SELECT
    'incidencia',
    i.incidencia_id,
    'Revisar incidencia ' || i.incidencia_id,
    'Comprobar estado y registrar actuación sobre la incidencia.',
    i.prioridad,
    CASE
        WHEN i.estado IN ('resuelta','cerrada') THEN 'realizada'
        WHEN i.estado = 'en_revision' THEN 'en_proceso'
        ELSE 'pendiente'
    END,
    CURRENT_DATE + CASE
        WHEN i.prioridad = 'critica' THEN 1
        WHEN i.prioridad = 'alta' THEN 2
        WHEN i.prioridad = 'media' THEN 5
        ELSE 10
    END,
    now(),
    now()
FROM app.incidencias i;

INSERT INTO app.tareas_pendientes
(origen, origen_id, titulo, descripcion, prioridad, estado, fecha_limite, creado_en, actualizado_en)
SELECT
    'matricula',
    m.matricula_id,
    'Revisar pago de ' || m.codigo_matricula,
    'La matrícula tiene importe pendiente de pago.',
    CASE
        WHEN m.fecha_matricula < CURRENT_DATE - INTERVAL '30 days' THEN 'alta'
        ELSE 'media'
    END,
    'pendiente',
    CURRENT_DATE + 7,
    now(),
    now()
FROM app.matriculas m
WHERE m.importe_pagado < m.importe_total
  AND m.estado <> 'anulada';
