-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 07_reporting.sql
-- Finalidad: Creación de vistas analíticas y reportes del sistema
-- ============================================================================

-- ============================================================================
-- 1. CAPA DE REPORTES (Consultas Analíticas y Vistas de Control)
-- ============================================================================

-- [Comentario Extra]: Vista básica para consultar el estado de saldos pendientes
CREATE OR REPLACE VIEW reporting.v_deuda_alumnos AS
SELECT
    a.alumno_id,
    a.nombre,
    a.apellidos,
    a.email,
    c.codigo AS codigo_curso,
    c.titulo AS curso,
    m.codigo_matricula,
    m.estado,
    m.importe_total,
    m.importe_pagado,
    m.importe_total - m.importe_pagado AS deuda
FROM app.matriculas m
JOIN app.alumnos a ON a.alumno_id = m.alumno_id
JOIN app.cursos c ON c.curso_id = m.curso_id;


-- [Comentario Extra]: Almacenamiento físico de métricas agregadas para mejorar el rendimiento
CREATE MATERIALIZED VIEW reporting.mv_resumen_cursos AS
SELECT
    c.curso_id,
    c.codigo,
    c.titulo,
    c.estado,
    c.plazas_totales,
    c.plazas_ocupadas,
    COUNT(m.matricula_id) AS matriculas,
    COALESCE(SUM(m.importe_total), 0) AS facturacion_prevista,
    COALESCE(SUM(m.importe_pagado), 0) AS facturacion_cobrada
FROM app.cursos c
LEFT JOIN app.matriculas m ON m.curso_id = c.curso_id
GROUP BY c.curso_id, c.codigo, c.titulo, c.estado, c.plazas_totales, c.plazas_ocupadas;

-- [Comentario Extra]: Índice único obligatorio para permitir el refresco rápido de la vista
CREATE UNIQUE INDEX idx_mv_resumen_cursos_curso_id
ON reporting.mv_resumen_cursos (curso_id);


-- ============================================================================
-- 2. TAREAS DE MANTENIMIENTO (Actualización de Datos Almacenados)
-- ============================================================================

-- ------------------------------------------------------------
-- Procedimiento: reporting.refrescar_informes()
-- ------------------------------------------------------------
-- Finalidad:
-- Refrescar la vista materializada reporting.mv_resumen_cursos.
--
-- Vista normal vs vista materializada:
-- - Una vista normal calcula los datos cada vez que se consulta.
-- - Una vista materializada guarda físicamente el resultado.
-- - Por eso, si cambian los datos origen, hay que refrescarla.
--
CREATE OR REPLACE PROCEDURE reporting.refrescar_informes()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Recalcula el contenido guardado de la vista materializada.
    REFRESH MATERIALIZED VIEW reporting.mv_resumen_cursos;
END;
$$;

-- Ejemplo de ejecución manual para pruebas:
-- CALL reporting.refrescar_informes();
-- SELECT * FROM reporting.mv_resumen_cursos;
