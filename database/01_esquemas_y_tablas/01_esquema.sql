-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 01_esquema.sql
-- Finalidad: Inicialización de base de datos, esquemas y tablas del negocio
-- ============================================================================

-- ============================================================================
-- 1. CONFIGURACIÓN INICIAL Y ESQUEMAS (Estructura Lógica y Extensiones)
-- ============================================================================

-- Preparación del entorno de base de datos:
-- Comandos para la eliminación física y creación del contenedor principal de datos
-- DROP DATABASE IF EXISTS dbsentinel;
-- CREATE DATABASE dbsentinel WITH OWNER = postgres ENCODING = 'UTF8' TEMPLATE = template0;
-- \c dbsentinel

-- Creación de espacios de nombres lógicos:
-- Aislamiento de capas del sistema para datos operativos, auditoría y reportes
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS reporting;

-- Inicialización de componentes criptográficos:
-- Carga de librerías nativas para funciones avanzadas de hashing y seguridad
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================================
-- 2. DEFINICIÓN DE ENTIDADES DEL NEGOCIO (Modelo Relacional de la Aplicación)
-- ============================================================================

-- Registro maestro de estudiantes:
-- Almacenamiento de datos personales, información de contacto y control de actividad
CREATE TABLE app.alumnos (
    alumno_id       BIGSERIAL PRIMARY KEY,
    dni             VARCHAR(20) NOT NULL UNIQUE,
    nombre          VARCHAR(80) NOT NULL,
    apellidos       VARCHAR(120) NOT NULL,
    email           VARCHAR(160) NOT NULL UNIQUE,
    telefono        VARCHAR(30),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Catálogo de oferta formativa:
-- Programación temporal de cursos académicos, control estricto de aforo y estados
CREATE TABLE app.cursos (
    curso_id         BIGSERIAL PRIMARY KEY,
    codigo           VARCHAR(20) NOT NULL UNIQUE,
    titulo           VARCHAR(160) NOT NULL,
    fecha_inicio     DATE NOT NULL,
    fecha_fin        DATE NOT NULL,
    plazas_totales   INTEGER NOT NULL CHECK (plazas_totales > 0),
    plazas_ocupadas  INTEGER NOT NULL DEFAULT 0 CHECK (plazas_ocupadas >= 0),
    estado           VARCHAR(20) NOT NULL DEFAULT 'planificado' 
                     CHECK (estado IN ('planificado','abierto','en_curso','finalizado','cancelado')),
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_curso_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT ck_curso_plazas CHECK (plazas_ocupadas <= plazas_totales)
);

-- Gestión de inscripciones académicas:
-- Vinculación de alumnos con programas formativos y trazabilidad financiera inicial
CREATE TABLE app.matriculas (
    matricula_id      BIGSERIAL PRIMARY KEY,
    codigo_matricula  VARCHAR(40) UNIQUE,
    alumno_id         BIGINT NOT NULL REFERENCES app.alumnos(alumno_id),
    curso_id          BIGINT NOT NULL REFERENCES app.cursos(curso_id),
    fecha_matricula   DATE NOT NULL DEFAULT CURRENT_DATE,
    estado            VARCHAR(20) NOT NULL DEFAULT 'pendiente_pago' 
                      CHECK (estado IN ('pendiente_pago','activa','anulada','finalizada')),
    importe_total     NUMERIC(10,2) NOT NULL CHECK (importe_total >= 0),
    importe_pagado    NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (importe_pagado >= 0),
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_matricula_alumno_curso UNIQUE (alumno_id, curso_id),
    CONSTRAINT ck_matricula_pago CHECK (importe_pagado <= importe_total)
);

-- Registro detallado de transacciones monetarias:
-- Historial físico de abonos realizados por los estudiantes mediante pasarelas válidas
CREATE TABLE app.pagos (
    pago_id       BIGSERIAL PRIMARY KEY,
    matricula_id  BIGINT NOT NULL REFERENCES app.matriculas(matricula_id),
    fecha_pago    DATE NOT NULL DEFAULT CURRENT_DATE,
    importe       NUMERIC(10,2) NOT NULL CHECK (importe > 0),
    metodo        VARCHAR(30) NOT NULL CHECK (metodo IN ('tarjeta','transferencia','efectivo','bizum')),
    referencia    VARCHAR(80),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Planificación de clases y aulas:
-- Cronograma diario por curso con validación de consistencia horaria
CREATE TABLE app.sesiones (
    sesion_id     BIGSERIAL PRIMARY KEY,
    curso_id      BIGINT NOT NULL REFERENCES app.cursos(curso_id),
    fecha_sesion  DATE NOT NULL,
    hora_inicio   TIME NOT NULL,
    hora_fin      TIME NOT NULL,
    aula          VARCHAR(40),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_sesion_horas CHECK (hora_fin > hora_inicio),
    CONSTRAINT uq_sesion_curso_fecha_hora UNIQUE (curso_id, fecha_sesion, hora_inicio)
);

-- Control de asistencia diaria:
-- Registro puntual del estado de presencia de los alumnos en cada sesión
CREATE TABLE app.asistencia (
    asistencia_id   BIGSERIAL PRIMARY KEY,
    sesion_id       BIGINT NOT NULL REFERENCES app.sesiones(sesion_id),
    matricula_id    BIGINT NOT NULL REFERENCES app.matriculas(matricula_id),
    estado          VARCHAR(20) NOT NULL DEFAULT 'presente' 
                    CHECK (estado IN ('presente','ausente','justificada')),
    observaciones   TEXT,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_asistencia_sesion_matricula UNIQUE (sesion_id, matricula_id)
);


-- ============================================================================
-- 3. SOPORTE OPERATIVO (Incidencias y Cola de Trabajo Interna)
-- ============================================================================

-- Gestión de tickets de soporte y reclamos:
-- Registro multicanal de eventos críticos para el seguimiento del alumno
CREATE TABLE app.incidencias (
    incidencial_id  BIGSERIAL PRIMARY KEY,
    matricula_id    BIGINT REFERENCES app.matriculas(matricula_id),
    tipo            VARCHAR(30) NOT NULL CHECK (tipo IN ('academica','administrativa','pago','asistencia')),
    prioridad       VARCHAR(20) NOT NULL DEFAULT 'media' 
                    CHECK (prioridad IN ('baja','media','alta','critica')),
    descripcion     TEXT NOT NULL,
    estado          VARCHAR(20) NOT NULL DEFAULT 'abierta' 
                    CHECK (estado IN ('abierta','en_revision','resuelta','cerrada')),
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cola de tareas pendientes del sistema:
-- Orquestación de flujos de trabajo internos y actividades pendientes de resolución
CREATE TABLE app.tareas_pendientes (
    tarea_id        BIGSERIAL PRIMARY KEY,
    origen          VARCHAR(40) NOT NULL,
    origen_id       BIGINT NOT NULL,
    titulo          VARCHAR(160) NOT NULL,
    descripcion     TEXT,
    prioridad       VARCHAR(20) NOT NULL DEFAULT 'media' 
                    CHECK (prioridad IN ('baja','media','alta','critica')),
    estado          VARCHAR(20) NOT NULL DEFAULT 'pendiente' 
                    CHECK (estado IN ('pendiente','en_proceso','realizada','cancelada')),
    fecha_limite    DATE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);
