-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 02_funciones_utilidad.sql
-- Finalidad: Lógica procedimental para auditoría funcional y cálculo de deuda
-- ============================================================================

-- ============================================================================
-- 1. EXTRACTORES DE IDENTIDAD OPERATIVA (Trazabilidad y Contexto de Sesión)
-- ============================================================================

-- ------------------------------------------------------------
-- Función: app.usuario_aplicacion()
-- ------------------------------------------------------------
-- Finalidad:
-- Devuelve el usuario funcional de la aplicación.
--
-- Problema que resuelve:
-- En muchas aplicaciones, todos los usuarios se conectan a PostgreSQL
-- usando una misma cuenta técnica, por ejemplo app_backend.
-- Si solo se guarda current_user, la auditoría siempre mostraría
-- esa cuenta técnica y no sabríamos qué usuario real hizo el cambio.
--
-- Funcionamiento:
-- 1. Intenta leer una variable de sesión llamada app.usuario.
-- 2. Si esa variable existe y tiene contenido, devuelve ese valor.
-- 3. Si no existe o está vacía, devuelve current_user, es decir,
-- el usuario real de PostgreSQL conectado.
--
-- Ejemplo:
-- SELECT set_config('app.usuario', 'profesor.francisco', false);
-- SELECT app.usuario_aplicacion();
--
-- [Comentario Extra]: Inicialización de la función analítica de contexto
CREATE OR REPLACE FUNCTION app.usuario_aplicacion()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
-- Variable local donde se guardará el valor de configuración app.usuario.
v_usuario TEXT;
BEGIN
-- current_setting lee una variable de configuración de PostgreSQL.
-- El segundo parámetro en true evita que falle si la variable no existe.
v_usuario := current_setting('app.usuario', true);

-- Si no hay usuario de aplicación, se usa el usuario de PostgreSQL.
-- btrim elimina espacios al principio y al final para detectar valores vacíos.
IF v_usuario IS NULL OR btrim(v_usuario) = '' THEN
RETURN current_user;
END IF;

-- Si app.usuario sí contiene un valor válido, se devuelve como usuario funcional.
RETURN v_usuario;
END;
$$;

-- Ejemplo de uso en una sesión:
-- [Comentario Extra]: Inyección de metadatos de usuario simulado en la sesión activa
SELECT set_config('app.usuario', 'profesor.francisco', false);

-- [Comentario Extra]: Verificación de la resolución de identidad esperada
SELECT app.usuario_aplicacion();


-- ============================================================================
-- 2. ENCAPSULACIÓN DE REGLAS DE NEGOCIO (Analítica Financiera de Matrículas)
-- ============================================================================

-- ------------------------------------------------------------
-- Función: app.deuda_matricula(p_matricula_id)
-- ------------------------------------------------------------
-- Finalidad:
-- Calcular cuánto dinero queda pendiente de pagar en una matrícula.
--
-- Parámetro:
-- p_matricula_id: identificador de la matrícula que se quiere consultar.
--
-- Devuelve:
-- importe_total - importe_pagado.
--
-- LANGUAGE sql:
-- Se usa porque la función solo contiene una consulta SQL sencilla.
--
-- STABLE:
-- Indica que la función no modifica datos y que, dentro de una misma
-- consulta, devolverá el mismo resultado si los datos no cambian.
--
-- [Comentario Extra]: Definición de la rutina optimizada para cálculo analítico de saldos
CREATE OR REPLACE FUNCTION app.deuda_matricula(p_matricula_id BIGINT)
RETURNS NUMERIC(10,2)
LANGUAGE sql
STABLE
AS $$
-- Se calcula la diferencia entre el importe total y lo que ya se ha pagado.
SELECT importe_total - importe_pagado
FROM app.matriculas
WHERE matricula_id = p_matricula_id;
$$;

-- Prueba, cuando existan matrículas:
-- [Comentario Extra]: Test unitario de validación de cálculo de deuda financiera
-- SELECT app.deuda_matricula(1);
