-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 10_consultas_auditoria.sql
-- Finalidad: Consultas de revisión para la bitácora JSONB, catálogo y negocio
-- ============================================================================

-- ============================================================================
-- 1. REVISIÓN DE LA BITÁCORA DE CAMBIOS (Consultas sobre logs JSONB)
-- ============================================================================

-- Cambios recientes:
-- Inspecciona las últimas transacciones globales guardadas en la bitácora
SELECT cambio_id, esquema, tabla, operacion, clave_primaria,
       usuario_app, usuario_bd, cambiado_en
FROM audit.cambios
ORDER BY cambiado_en DESC
LIMIT 20;

-- Ver cambios de una matrícula concreta:
-- Extrae la historia clínica y trazabilidad completa filtrando por la clave JSONB
SELECT cambio_id, operacion, datos_anteriores, datos_nuevos, cambiado_en
FROM audit.cambios
WHERE tabla = 'matriculas'
  AND clave_primaria ->> 'id' = '1'
ORDER BY cambiado_en;

-- Ver únicamente cambios de estado de matrículas:
-- Aislamiento exacto de transiciones de estados mediante análisis delta de JSONB
SELECT cambio_id,
       datos_anteriores ->> 'estado' AS estado_anterior,
       datos_nuevos ->> 'estado' AS estado_nuevo,
       cambiado_en
FROM audit.cambios
WHERE tabla = 'matriculas'
  AND operacion = 'UPDATE'
  AND datos_anteriores ->> 'estado' IS DISTINCT FROM datos_nuevos ->> 'estado';


-- ============================================================================
-- 2. REVISIÓN TÉCNICA DEL MOTOR (Consultas al Catálogo Interno)
-- ============================================================================

-- Listar triggers de tablas de la aplicación:
-- Muestra los metadatos de los disparadores activos en el esquema operativo
SELECT event_object_schema AS esquema,
       event_object_table AS tabla,
       trigger_name,
       action_timing,
       event_manipulation,
       action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'app'
ORDER BY event_object_table, trigger_name;

-- Ver definición de una función:
-- Ingeniería inversa para extraer el código fuente original desde SQL
SELECT pg_get_functiondef('app.trg_set_actualizado_en()'::regprocedure);

-- Desactivar temporalmente un trigger concreto:
-- Comandos útiles para tareas de mantenimiento o cargas masivas externas
-- ALTER TABLE app.matriculas DISABLE TRIGGER control_plazas_matricula;

-- Reactivar el trigger:
-- ALTER TABLE app.matriculas ENABLE TRIGGER control_plazas_matricula;

-- Ver triggers definidos directamente desde catálogo:
-- Consulta de bajo nivel directa al catálogo interno de PostgreSQL
SELECT tgname AS trigger, relname AS tabla, tgenabled AS activo
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
  AND NOT t.tgisinternal
ORDER BY relname, tgname;
-- ============================================================================
-- 3. VALIDACIÓN DE DATOS DEL NEGOCIO (Control de Saldos y Totales)
-- ============================================================================

-- Conteo de registros totales por cada tabla para el cuadro de mandos
SELECT 'alumnos' AS tabla, COUNT(*) AS registros FROM app.alumnos
UNION ALL SELECT 'cursos', COUNT(*) FROM app.cursos
UNION ALL SELECT 'matriculas', COUNT(*) FROM app.matriculas
UNION ALL SELECT 'pagos', COUNT(*) FROM app.pagos
UNION ALL SELECT 'sesiones', COUNT(*) FROM app.sesiones
UNION ALL SELECT 'asistencia', COUNT(*) FROM app.asistencia
UNION ALL SELECT 'incidencias', COUNT(*) FROM app.incidencias
UNION ALL SELECT 'tareas_pendientes', COUNT(*) FROM app.tareas_pendientes
ORDER BY tabla;

-- Balance analítico de plazas ocupadas frente a las inscripciones reales del negocio
SELECT c.codigo,
       c.titulo,
       c.plazas_totales,
       c.plazas_ocupadas,
       COUNT(m.matricula_id) AS matriculas_reales
FROM app.cursos c
LEFT JOIN app.matriculas m ON m.curso_id = c.curso_id
  AND m.estado IN ('pendiente_pago','activa','finalizada')
GROUP BY c.curso_id, c.codigo, c.titulo, c.plazas_totales, c.plazas_ocupadas
ORDER BY c.codigo;

-- Análisis de riesgo financiero: Alumnos deudores con saldos pendientes de pago
SELECT m.codigo_matricula,
       a.nombre || ' ' || a.apellidos AS alumno,
       c.codigo AS curso,
       m.estado,
       m.importe_total,
       m.importe_pagado,
       (m.importe_total - m.importe_pagado) AS pendiente
FROM app.matriculas m
JOIN app.alumnos a ON a.alumno_id = m.alumno_id
JOIN app.cursos c ON c.curso_id = m.curso_id
WHERE m.importe_pagado < m.importe_total
ORDER BY pendiente DESC, m.codigo_matricula;

-- Cierre definitivo y consolidación física de la transacción de datos de prueba
COMMIT;