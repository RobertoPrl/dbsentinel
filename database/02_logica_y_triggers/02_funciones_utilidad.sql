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

/*******************************************************************************
 * Nombre completo de un alumno
 * Tipo: Función sin trigger
 * Objetivo: Crear una función sencilla que consulte datos de app.alumnos.
 * Crear la función app.ej_nombre_completo_alumno(p_alumno_id BIGINT) 
 *            que devuelva en un único texto el nombre y los apellidos del 
 *            alumno. Si el alumno no existe, debe devolver NULL.
 * Requisitos mínimos: 
 *  • Debe devolver TEXT. 
 *  • Debe consultar la tabla app.alumnos. 
 *  • Debe eliminar espacios sobrantes con btrim o concat_ws si lo consideras oportuno.
 *******************************************************************************/
CREATE OR REPLACE FUNCTION  app.ej_nombre_completo_alumno(p_alumno_id BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
	v_alumno TEXT;
	v_nombre TEXT;
	v_apellidos TEXT;
BEGIN
	-- Consulta los datos del alumno por ID y los guarda en las variables
	SELECT nombre, apellidos
	INTO v_nombre, v_apellidos
	FROM app.alumnos
	WHERE alumno_id= p_alumno_id;

	-- Comprueba si el alumno existe en la tabla
	IF FOUND THEN
		-- Concatena el nombre y los apellidos con el operador ||
		v_alumno := v_nombre ||' '|| v_apellidos;
		RETURN v_alumno;
	ELSE
		-- Si no existe, devuelve NULL
		RETURN NULL;
	END IF;
END;
$$;


/*******************************************************************************
 * Días desde la matrícula
 * Tipo: Función sin trigger
 * Objetivo: Calcular un dato temporal a partir de la fecha de matrícula.
 * Crear la función app.ej_dias_desde_matricula(p_matricula_id BIGINT) 
 *            que devuelva cuántos días han pasado desde fecha_matricula hasta 
 *            CURRENT_DATE.
 * Requisitos mínimos: 
 *  • Debe devolver INTEGER. 
 *  • Si la matrícula no existe, puede devolver NULL. 
 *  • No debe modificar datos.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION  app.ej_dias_desde_matricula(p_matricula_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
	v_fecha_matricula DATE;
BEGIN
	-- Consulta la fecha de la matrícula por ID y la guarda en la variable
	SELECT fecha_matricula
	INTO v_fecha_matricula
	FROM app.matriculas
	WHERE matricula_id= p_matricula_id;

	-- Resta la fecha actual menos la de matrícula para obtener los días
	RETURN CURRENT_DATE-v_fecha_matricula;
END;
$$;

/*******************************************************************************
 * Clasificar matrícula según el importe pagado
 * Tipo: Función sin trigger
 * Objetivo: Clasificar una matrícula según el importe que tiene pagado.
 * Crear la función app.ej_estado_pago_matricula(p_matricula_id BIGINT) 
 *            que devuelva sin_pago, parcial, pagada o inexistente.
 * Requisitos mínimos: 
 *  • Debe devolver TEXT. 
 *  • Si importe_pagado = 0, devolver sin_pago. 
 *  • Si importe_pagado es menor que importe_total, devolver parcial. 
 *  • Si importe_pagado es igual o superior a importe_total, devolver pagada. 
 *  • Si no existe la matrícula, devolver inexistente.
 *******************************************************************************/


CREATE OR REPLACE FUNCTION  app.ej_estado_pago_matricula(p_matricula_id BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
	v_importe_pagado INTEGER;
	v_importe_total INTEGER;
BEGIN
	-- Consulta los importes de la matrícula y los guarda en las variables
	SELECT importe_total, importe_pagado
	INTO v_importe_total, v_importe_pagado
	FROM app.matriculas
	WHERE matricula_id= p_matricula_id;

	-- Evalúa el estado del pago según las condiciones del enunciado
	IF v_importe_pagado=0 THEN 
		RETURN 'sin pago';
	ELSIF v_importe_pagado<v_importe_total THEN
		RETURN 'parcial';
	ELSIF v_importe_pagado>=v_importe_total THEN
		RETURN 'pagada';
	ELSE 
		-- Si las variables son NULL (matrícula inexistente), salta al ELSE
		RETURN 'inexistente';
	END IF;
END;
$$;

/*******************************************************************************
 * Total pagado por un alumno
 * Tipo: Función sin trigger
 * Objetivo: Practicar JOIN y agregación dentro de una función.
 * Crear la función app.ej_total_pagado_alumno(p_alumno_id BIGINT) 
 *            que devuelva la suma de todos los pagos realizados por las 
 *            matrículas de ese alumno.
 * Requisitos mínimos: 
 *  • Debe devolver NUMERIC(10,2). 
 *  • Debe usar app.matriculas y app.pagos. 
 *  • Si no hay pagos, debe devolver 0.00.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION  app.ej_total_pagado_alumno(p_alumno_id BIGINT)
RETURNS NUMERIC(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
	v_importe_total_pagado NUMERIC(10,2);
BEGIN
	-- Calcula la suma de pagos del alumno uniendo ambas tablas y controla el valor NULL
	SELECT COALESCE(SUM(p.importe), 0.00)
	INTO v_importe_total_pagado
	FROM app.matriculas m
	INNER JOIN app.pagos p ON m.matricula_id = p.matricula_id
	WHERE m.alumno_id = p_alumno_id;
	
	-- Devuelve el total acumulado
	RETURN v_importe_total_pagado;
END;
$$;

/*******************************************************************************
 * Número de matrículas activas de un curso
 * Tipo: Función sin trigger
 * Objetivo: Contar registros relacionados a partir del código de curso.
 * Crear la función app.ej_num_matriculas_curso(p_codigo_curso VARCHAR) 
 *            que devuelva cuántas matrículas no anuladas tiene un curso.
 * Requisitos mínimos: 
 *  • Debe devolver INTEGER. 
 *  • Debe buscar el curso por app.cursos.codigo. 
 *  • Debe excluir las matrículas en estado anulada.
 * Entrega esperada: Función y SELECT de prueba comparando varios cursos.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION  app.ej_num_matriculas_curso(p_codigo_curso VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
	v_num_matriculas INTEGER;
BEGIN
	-- Cuenta las matrículas del curso uniendo las tablas y aplicando los filtros
	SELECT COUNT(*)
	INTO v_num_matriculas
	FROM app.cursos c
	INNER JOIN app.matriculas m ON m.curso_id = c.curso_id
	WHERE m.estado != 'anulada'
	AND c.codigo = p_codigo_curso;
	
	-- Devuelve el número total de matrículas encontradas
	RETURN v_num_matriculas;
END;
$$;

/*******************************************************************************
 * Porcentaje de ocupación de un curso
 * Tipo: Función sin trigger
 * Objetivo: Calcular una métrica a partir de plazas_totales y plazas_ocupadas.
 * Crear la función app.ej_porcentaje_ocupacion_curso(p_codigo_curso VARCHAR) 
 *            que devuelva el porcentaje de ocupación del curso.
 * Requisitos mínimos: 
 *  • Debe devolver NUMERIC(5,2). 
 *  • La fórmula es plazas_ocupadas * 100 / plazas_totales.
 *  • Debe redondear a 2 decimales. 
 *  • Si el curso no existe, devolver NULL.
 * Entrega esperada: Función y consulta de prueba con app.cursos.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION  app.ej_porcentaje_ocupacion_curso(p_codigo_curso VARCHAR)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
	v_metrica NUMERIC(5,2);
BEGIN
	-- Calcula el porcentaje con seguridad ante división por cero y redondea a 2 decimales
	SELECT ROUND(plazas_ocupadas * 100.0 / NULLIF(plazas_totales, 0),2)
	INTO v_metrica
	FROM app.cursos c
	WHERE c.codigo = p_codigo_curso;
	
	-- Devuelve la métrica calculada o NULL si el curso no existe
	RETURN v_metrica;

END;
$$;

/*******************************************************************************
 * Comprobar incidencias abiertas de una matrícula
 * Tipo: Función sin trigger
 * Objetivo: Crear una función booleana con EXISTS.
 * Crear la función app.ej_tiene_incidencias_abiertas(p_matricula_id BIGINT) 
 *            que indique si una matrícula tiene alguna incidencia abierta o en revisión.
 * Requisitos mínimos: 
 *  • Debe devolver BOOLEAN. 
 *  • Debe considerar los estados abierta y en_revision. 
 *  • Debe usar EXISTS.
 * Entrega esperada: Función y consulta sobre varias matrículas.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION  app.ej_tiene_incidencias_abiertas(p_matricula_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
	v_incidencia_matriculas BOOLEAN;
BEGIN
	-- Evalúa si existen incidencias en estado 'abierta' o 'en_revision' para la matrícula
	SELECT EXISTS (
		SELECT 1 
		FROM app.incidencias i
		WHERE i.matricula_id = p_matricula_id
		  AND i.estado IN ('abierta', 'en_revision')
	) INTO v_incidencia_matriculas;

	-- Devuelve el resultado booleano (TRUE o FALSE)
	RETURN v_incidencia_matriculas;
END;
$$;

/*******************************************************************************
 * Comprobar si un alumno puede matricularse en un curso
 * Tipo: Función sin trigger
 * Objetivo: Agrupar varias reglas sencillas en una función PL/pgSQL.
 * Crear la función app.ej_puede_matricularse(p_dni VARCHAR, p_codigo_curso VARCHAR) 
 *            que devuelva TRUE si el alumno existe, está activo, el curso está abierto, 
 *            no existe ya una matrícula para ese alumno y curso, y quedan plazas libres.
 * Requisitos mínimos: 
 *  • Debe devolver BOOLEAN. 
 *  • Debe consultar app.alumnos, app.cursos y app.matriculas. 
 *  • Debe devolver FALSE si no se cumple alguna condición.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION app.ej_puede_matricularse(p_dni VARCHAR, p_codigo_curso VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
	v_alumno_id BIGINT;
	v_alumno_activo BOOLEAN;
	v_curso_id BIGINT;
	v_curso_estado VARCHAR;
	v_plazas_libres INTEGER;
	v_ya_matriculado BOOLEAN;
BEGIN
	-- 1. VALIDACIÓN DEL ALUMNO: ¿Existe y está activo?
	SELECT alumno_id, activo 
	INTO v_alumno_id, v_alumno_activo
	FROM app.alumnos
	WHERE dni = p_dni;

	IF NOT FOUND OR v_alumno_activo = FALSE THEN
		RETURN FALSE;
	END IF;

	-- 2. VALIDACIÓN DEL CURSO: ¿Existe, está abierto y tiene plazas libres?
	SELECT curso_id, estado, (plazas_totales - plazas_ocupadas)
	INTO v_curso_id, v_curso_estado, v_plazas_libres
	FROM app.cursos
	WHERE codigo = p_codigo_curso;

	-- Cambia 'abierto' por el término exacto que use tu tabla (ej: 'activo', 'open', etc.)
	IF NOT FOUND OR v_curso_estado <> 'abierto' OR v_plazas_libres <= 0 THEN
		RETURN FALSE;
	END IF;

	-- 3. VALIDACIÓN DE DUPLICADOS: ¿Ya existe una matrícula activa para este alumno en este curso?
	SELECT EXISTS (
		SELECT 1 
		FROM app.matriculas
		WHERE alumno_id = v_alumno_id 
		  AND curso_id = v_curso_id
		  AND estado <> 'anulada' -- Excluimos matrículas anuladas del pasado
	) INTO v_ya_matriculado;

	IF v_ya_matriculado THEN
		RETURN FALSE;
	END IF;

	-- Si ha superado todos los filtros y "muros" anteriores de validación, puede matricularse
	RETURN TRUE;
END;
$$;

/*******************************************************************************
 * Próxima sesión de un curso
 * Tipo: Función sin trigger
 * Objetivo: Buscar la siguiente fecha de sesión a partir del día actual.
 * Crear la función app.ej_proxima_sesion_curso(p_codigo_curso VARCHAR) 
 *            que devuelva la fecha de la próxima sesión de ese curso.
 * Requisitos mínimos: 
 *  • Debe devolver DATE. 
 *  • Debe usar app.cursos y app.sesiones. 
 *  • Debe buscar sesiones con fecha_sesion >= CURRENT_DATE. 
 *  • Si no hay próximas sesiones, devolver NULL.
 *******************************************************************************/

CREATE OR REPLACE FUNCTION app.ej_proxima_sesion_curso(p_codigo_curso VARCHAR)
RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
	v_proxima_fecha DATE;
BEGIN
	-- Buscamos la fecha más cercana uniendo cursos y sesiones
	SELECT s.fecha_sesion
	INTO v_proxima_fecha
	FROM app.cursos c
	INNER JOIN app.sesiones s ON c.curso_id = s.curso_id -- Conexión de tablas por curso_id
	WHERE c.codigo = p_codigo_curso
	  AND s.fecha_sesion >= CURRENT_DATE -- Requisito: fecha igual o posterior a hoy
	ORDER BY s.fecha_sesion ASC -- Ordenamos de la más cercana a la más lejana
	LIMIT 1;                    -- Nos quedamos solo con la más inmediata

	-- Si no se encuentra ninguna fila, v_proxima_fecha se queda como NULL automáticamente
	RETURN v_proxima_fecha;
END;
$$;

/*******************************************************************************
 * Resumen textual de una matrícula
 * Tipo: Función sin trigger
 * Objetivo: Construir un texto combinando datos de alumno, curso y matrícula.
 * Crear la función app.ej_resumen_matricula(p_matricula_id BIGINT) 
 *            que devuelva un texto con código de matrícula, alumno, curso, 
 *            estado y deuda pendiente.
 * Requisitos mínimos: 
 *  • Debe devolver TEXT. 
 *  • Debe usar JOIN entre app.matriculas, app.alumnos y app.cursos. 
 *  • Si la matrícula no existe, devolver "Matrícula no encontrada".
 *******************************************************************************/

CREATE OR REPLACE FUNCTION app.ej_resumen_matricula(p_matricula_id BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
	v_codigo_mat VARCHAR;
	v_nom_alumno TEXT;
	v_ape_alumno TEXT;
	v_nom_curso VARCHAR;
	v_estado_mat VARCHAR;
	v_deuda NUMERIC(10,2);
	v_resumen TEXT;
BEGIN
	-- Consultamos y unimos las tres tablas a la vez
	SELECT 
		m.codigo_matricula,
		c.nombre, 
		a.nombre, 
		a.apellidos, 
		m.estado, 
		(m.importe_total - m.importe_pagado)
	INTO 
		v_codigo_mat, 
		v_nom_curso, 
		v_nom_alumno, 
		v_ape_alumno, 
		v_estado_mat, 
		v_deuda
	FROM app.matriculas m
	INNER JOIN app.alumnos a ON m.alumno_id = a.alumno_id
	INNER JOIN app.cursos c ON m.curso_id = c.curso_id
	WHERE m.matricula_id = p_matricula_id;

	-- Verificamos si la matrícula existe
	IF FOUND THEN
		v_resumen := 'Matrícula: ' || v_codigo_mat || 
		             ' | Alumno: ' || BTRIM(v_nom_alumno || ' ' || v_ape_alumno) || 
		             ' | Curso: ' || v_nom_curso || 
		             ' | Estado: ' || v_estado_mat || 
		             ' | Deuda: ' || v_deuda || '€';
		RETURN v_resumen;
	ELSE
		-- Requisito estricto: Si no existe, devolver este texto
		RETURN 'Matrícula no encontrada';
	END IF;
END;
$$;

