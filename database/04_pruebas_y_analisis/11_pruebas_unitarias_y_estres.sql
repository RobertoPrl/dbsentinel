-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 11_pruebas_unitarias_y_estres.sql [PARTE 1]
-- Tipo: Banco de Pruebas de Integración 
-- Objetivo: Validar integridad referencial y lógica de negocio mediante triggers.
-- ============================================================================

-- ============================================================================
-- FASE 1: INSPECCIÓN DE METADATOS Y CATÁLOGO INTERNO
-- ============================================================================

-- 1. Auditoría del diccionario de datos: Verificar triggers activos en esquema app
-- [Resultado esperado]: Grid con metadatos técnicos de los disparadores activos.
SELECT 
    event_object_table AS tabla,
    trigger_name, 
    action_timing, 
    event_manipulation, 
    action_statement 
FROM information_schema.triggers 
WHERE event_object_schema = 'app' 
ORDER BY event_object_table, trigger_name; 

-- 2. Ingeniería inversa del catálogo: Extraer definiciones DDL explícitas
-- [Resultado esperado]: Código fuente procedural asociado a la propiedad OID.
SELECT 
    n.nspname AS esquema, 
    c.relname AS tabla, 
    t.tgname AS trigger,
    pg_get_triggerdef(t.oid) AS definicion 
FROM pg_trigger t 
JOIN pg_class c ON c.oid = t.tgrelid 
JOIN pg_namespace n ON n.oid = c.relnamespace 
WHERE n.nspname = 'app' 
  AND NOT t.tgisinternal 
ORDER BY c.relname, t.tgname; 

-- ============================================================================
-- FASE 2: PRUEBAS DE SANEAMIENTO Y LOGS TEMPORALES
-- ============================================================================

-- 3. Verificación de normalización automática de strings (Trigger BEFORE INSERT)
-- [Alineación]: Simula la inserción de datos corruptos/sucios desde la app web.
INSERT INTO app.alumnos (dni, nombre, apellidos, email, telefono) 
VALUES ( 
    '99999999A', 
    'Prueba', 
    'Email Normalizado', 
    ' PRUEBA.EMAIL@EXAMPLE.COM ', 
    '600000000' 
); 

-- [Resultado esperado]: Correo sanitizado en minúsculas y sin espacios ('prueba.email@example.com').
SELECT dni, email FROM app.alumnos WHERE dni = '99999999A'; 

-- 4. Verificación del comportamiento del timestamp delta (Trigger BEFORE UPDATE)
SELECT alumno_id, nombre, creado_en, actualizado_en 
FROM app.alumnos WHERE dni = '99999999A'; 

-- Mutación del estado del registro para disparar el evento temporal:
UPDATE app.alumnos SET nombre = 'Prueba Modificada' WHERE dni = '99999999A'; 

-- [Resultado esperado]: 'actualizado_en' cambia al timestamp actual; 'creado_en' queda inmutable.
SELECT alumno_id, nombre, creado_en, actualizado_en 
FROM app.alumnos WHERE dni = '99999999A'; 

-- ============================================================================
-- FASE 3: VALIDACIÓN DE RESTRICCIONES DE NEGOCIO Y CONCURRENCIA
-- ============================================================================

-- 5. Stress Test: Restricciones lógicas transaccionales en Cursos
-- Intento A [Resultado esperado]: EXCEPCIÓN. Bloqueo por fecha de fin menor a inicio.
INSERT INTO app.cursos (codigo, titulo, fecha_inicio, fecha_fin, plazas_totales, estado) 
VALUES ('CURSO-ERROR-01', 'Curso con fechas incorrectas', CURRENT_DATE + 10, CURRENT_DATE + 5, 10, 'abierto'); 

-- Intento B [Resultado esperado]: EXCEPCIÓN. Bloqueo de estado 'en_curso' para fechas futuras.
INSERT INTO app.cursos (codigo, titulo, fecha_inicio, fecha_fin, plazas_totales, estado) 
VALUES ('CURSO-ERROR-02', 'Curso futuro en curso', CURRENT_DATE + 10, CURRENT_DATE + 30, 10, 'en_curso'); 

-- 6. Flujo óptimo: Inserción base para ciclo de matrículas
-- [Resultado esperado]: Inserción exitosa del entorno controlado (Cupo limitado a 2 plazas).
INSERT INTO app.cursos (codigo, titulo, fecha_inicio, fecha_fin, plazas_totales, estado) 
VALUES ('TRG-MAT-01', 'Curso de prueba de matrículas', CURRENT_DATE, CURRENT_DATE + 30, 2, 'abierto'); 

INSERT INTO app.alumnos (dni, nombre, apellidos, email, telefono) 
VALUES ('88888888B', 'Alumno', 'Matricula Uno', 'alumno.matricula1@example.com', '600111111'); 

-- Generación automatizada de códigos secuenciales de negocio (MAT-2026-...):
INSERT INTO app.matriculas (alumno_id, curso_id, importe_total) 
SELECT a.alumno_id, c.curso_id, 300.00 
FROM app.alumnos a JOIN app.cursos c ON c.codigo = 'TRG-MAT-01' WHERE a.dni = '88888888B'; 

-- [Resultado esperado]: Visualizar código autogenerado y estado 'pendiente_pago'.
SELECT codigo_matricula, estado, importe_total, importe_pagado 
FROM app.matriculas WHERE alumno_id = (SELECT alumno_id FROM app.alumnos WHERE dni = '88888888B'); 

-- 7. Simulación de saturación física de plazas (Race Conditions Control)
-- Registro del segundo alumno (Consume la plaza límite número 2):
INSERT INTO app.alumnos (dni, nombre, apellidos, email, telefono) 
VALUES ('77777777C', 'Alumno', 'Matricula Dos', 'alumno.matricula2@example.com', '600222222'); 

INSERT INTO app.matriculas (alumno_id, curso_id, importe_total) 
SELECT a.alumno_id, c.curso_id, 300.00 
FROM app.alumnos a JOIN app.cursos c ON c.codigo = 'TRG-MAT-01' WHERE a.dni = '77777777C'; 

-- [Resultado esperado]: El contador dinámico 'plazas_ocupadas' incrementa a 2.
SELECT codigo, plazas_totales, plazas_ocupadas FROM app.cursos WHERE codigo = 'TRG-MAT-01'; 

-- Inserción de desborde: Intento de registro de un tercer alumno en curso lleno.
INSERT INTO app.alumnos (dni, nombre, apellidos, email, telefono) 
VALUES ('66666666D', 'Alumno', 'Matricula Tres', 'alumno.matricula3@example.com', '600333333'); 

-- [Resultado esperado]: EXCEPCIÓN controlada por Trigger de cupos (ERROR: No quedan plazas).
INSERT INTO app.matriculas (alumno_id, curso_id, importe_total) 
SELECT a.alumno_id, c.curso_id, 300.00 
FROM app.alumnos a JOIN app.cursos c ON c.codigo = 'TRG-MAT-01' WHERE a.dni = '66666666D'; 

-- 8. Verificación de liberación dinámica de recursos ante bajas de negocio
UPDATE app.matriculas SET estado = 'anulada'
WHERE matricula_id = (SELECT m.matricula_id FROM app.matriculas m JOIN app.cursos c ON c.curso_id = m.curso_id WHERE c.codigo = 'TRG-MAT-01' LIMIT 1); 

-- [Resultado esperado]: El contador dinámico 'plazas_ocupadas' decrementa automáticamente a 1.
SELECT codigo, plazas_totales, plazas_ocupadas FROM app.cursos WHERE codigo = 'TRG-MAT-01'; 

-- ============================================================================
-- FASE 4: AUDITORÍA FINANCIERA Y MÁQUINAS DE ESTADO 
-- ============================================================================

-- 9. Transición automática de estados contables mediante flujos de cobro
-- Balance inicial en deuda (Pendiente):
SELECT matricula_id, codigo_matricula, estado, importe_total, importe_pagado 
FROM app.matriculas WHERE importe_pagado = 0 LIMIT 1; 

-- Abono Parcial: El estado conserva la deuda calculada.
INSERT INTO app.pagos (matricula_id, importe, metodo, referencia) 
VALUES (1, 100.00, 'tarjeta', 'TPV-PRUEBA-001'); 

-- Abono de Liquidación total para saldar la deuda pendiente:
INSERT INTO app.pagos (matricula_id, importe, metodo, referencia) 
SELECT matricula_id, importe_total - importe_pagado, 'tarjeta', 'TPV-PRUEBA-002' 
FROM app.matriculas WHERE matricula_id = 1; 

-- [Resultado esperado]: El trigger liquida cuentas y conmuta el estado a 'activa'.
SELECT matricula_id, codigo_matricula, estado, importe_total, importe_pagado FROM app.matriculas WHERE matricula_id = 1; 

-- 10. Seguridad Financiera: Protección ante desbordamiento de cobros (Overpayment Prevention)
-- [Resultado esperado]: EXCEPCIÓN controlada por motor. (ERROR: Importe supera deuda pendiente).
INSERT INTO app.pagos (matricula_id, importe, metodo, referencia) 
VALUES (1, 99999.00, 'tarjeta', 'TPV-ERROR'); 

-- ============================================================================
-- FASE 5: AUTOMATIZACIÓN DE PROCESOS Y TRAZABILIDAD
-- ============================================================================

-- 11. Pipeline automatizado: Orquestación indirecta de tareas secundarias (SLA Support)
INSERT INTO app.incidencias (matricula_id, tipo, prioridad, descripcion) 
VALUES (1, 'pago', 'alta', 'El alumno solicita revisión urgente del pago.'); 

INSERT INTO app.incidencias (matricula_id, tipo, prioridad, descripcion) 
VALUES (1, 'academica', 'critica', 'El alumno no puede acceder al aula virtual.'); 

-- [Resultado esperado]: Tareas generadas de forma asíncrona con cálculo dinámico de SLAs (fechas límite).
SELECT tarea_id, origen, origen_id, titulo, prioridad, estado, fecha_limite FROM app.tareas_pendientes ORDER BY tarea_id DESC LIMIT 5; 

-- 12. Trazabilidad del contexto de aplicación e inspección del log delta JSONB
-- Inyección manual de variables de entorno de la app en la sesión del motor:
SELECT set_config('app.usuario', 'alumno.prueba', false); 

-- Mutación protegida sobre registros operacionales:
UPDATE app.matriculas SET estado = 'anulada' WHERE matricula_id = 1; 

-- [Resultado esperado]: Trazabilidad del usuario de la app guardada en el esquema analítico.
SELECT cambio_id, esquema, tabla, operacion, usuario_app, cambiado_en FROM audit.cambios ORDER BY cambio_id DESC LIMIT 10; 

-- [Resultado esperado]: Extracción diferencial mediante operadores JSONB (Estados antes vs después).
SELECT cambio_id, datos_anteriores ->> 'estado' AS antes, datos_nuevos ->> 'estado' AS despues, usuario_app FROM audit.cambios WHERE tabla = 'matriculas' ORDER BY cambio_id DESC LIMIT 10; 

-- 13. Eventos asíncronos distribuidos en tiempo real (Event-Driven Architecture)
-- Terminal 1 (Escucha activa del socket):
LISTEN incidencias_criticas; 

-- Terminal 2 (Disparador interproceso - Descomentar para pruebas de señalización física):
-- INSERT INTO app.incidencias (matricula_id, tipo, prioridad, descripcion) 
-- VALUES (1, 'academica', 'critica', 'Prueba de notificación con LISTEN y NOTIFY.'); 

-- ============================================================================
-- FASE 6: CONSOLIDACIÓN DE DATOS
-- ============================================================================

-- 14. Reporte analítico consolidado de consistencia y volumen de objetos físicos
-- [Resultado esperado]: Métrica unificada de filas por tabla de control operacional.
SELECT 'alumnos' AS tabla, COUNT(*) FROM app.alumnos 
UNION ALL SELECT 'cursos', COUNT(*) FROM app.cursos 
UNION ALL SELECT 'matriculas', COUNT(*) FROM app.matriculas 
UNION ALL SELECT 'pagos', COUNT(*) FROM app.pagos 
UNION ALL SELECT 'incidencias', COUNT(*) FROM app.incidencias 
UNION ALL SELECT 'tareas_pendientes', COUNT(*) FROM app.tareas_pendientes 
UNION ALL SELECT 'auditoria', COUNT(*) FROM audit.cambios 
ORDER BY tabla;
