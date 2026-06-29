-- ============================================================================
-- SISTEMA CORE DB-SENTINEL (POSTGRESQL ARCHITECTURE)
-- Script: 00_crear_bd.sql
-- Finalidad: Inicialización física del contenedor y preparación del entorno
-- ============================================================================

-- ============================================================================
-- 1. CONTROL DE CONTENEDORES (Creación física de la Base de Datos)
-- ============================================================================

-- Nota técnica: 
-- Estos comandos iniciales limpian el entorno para poder reinstalar desde cero.
-- Se recomienda ejecutarlos conectado a la base de datos por defecto 'postgres'.

-- Eliminación defensiva:
-- Borra la base de datos si ya existe para evitar errores de duplicidad
DROP DATABASE IF EXISTS dbsentinel;

-- Creación física:
-- Configura el nuevo contenedor de datos con codificación UTF8 estándar
CREATE DATABASE dbsentinel 
    WITH OWNER = postgres 
    ENCODING = 'UTF8' 
    TEMPLATE = template0;

-- Conexión operativa:
-- Cambia el contexto de la sesión actual hacia la nueva base de datos creada
\c dbsentinel

-- Mensaje de control:
-- Confirmación visual de la inicialización correcta del entorno dbsentinel
SELECT 'Base de datos dbsentinel inicializada correctamente.' AS estado;
