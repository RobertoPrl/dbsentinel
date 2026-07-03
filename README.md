# 🛡️ Base de Datos DB-Sentinel

Sistema de automatización de reglas de negocio, control de plazas y motor de auditoría transaccional desarrollado sobre **PostgreSQL**. 

Este proyecto simula la base de datos para un centro de formación académica, implementando la lógica directamente en el servidor para asegurar que los datos estén siempre protegidos, correctos y bien auditados.

## 🚀 Puntos Clave del Proyecto
*   **Control de Plazas Seguro:** Evita la sobreventa de plazas en inscripciones simultáneas usando bloqueos automáticos en las filas (`SELECT ... FOR UPDATE`).
*   **Historial de Cambios Inteligente:** Guarda un registro de cada inserción, modificación o borrado de datos convirtiendo las filas a formato **JSONB** para que sea fácil consultar el antes y el después.
*   **Rastreo de Usuarios Real:** Captura el nombre del usuario real que hace los cambios a través de variables de sesión, diferenciándolo de la cuenta técnica que usa la aplicación para conectarse.
*   **Alertas Instantáneas:** Envía avisos de forma inmediata ante incidencias críticas usando los canales nativos `LISTEN` y `NOTIFY` de PostgreSQL.

---

## 📁 Estructura del Repositorio

El proyecto está organizado en las siguientes subcarpetas para separar la estructura de las tablas de la lógica interna:

```text
DB-Sentinel/
│
├── 📄 README.md                    # Presentación del proyecto y guía de instalación
│
└── 📁 database/
    │
    ├── 📄 00_crear_bd.sql           # Inicialización básica de la base de datos
    │
    ├── 📁 01_esquemas_y_tablas/
    │   ├── 📄 01_esquema.sql       # Estructura de tablas de la aplicación
    │   └── 📄 05_auditoria.sql     # Estructura de las tablas de auditoría
    │
    ├── 📁 02_logica_y_triggers/
    │   ├── 📄 02_funciones_utilidad.sql
    │   ├── 📄 03_triggers_basicos.sql
    │   ├── 📄 04_triggers_negocio.sql
    │   └── 📄 08_notify.sql
    │
    ├── 📁 03_componentes_avanzados/
    │   ├── 📄 06_procedimientos.sql
    │   └── 📄 07_reporting.sql
    │
    └── 📁 04_pruebas_y_analisis/
        ├── 📄 09_datos_prueba.sql
        └── 📄 10_consultas_auditoria.sql
```

---

## ⚙️ Paso a Paso para Instalar la Base de Datos

Para que todo funcione correctamente y no salten errores de dependencias (como intentar crear un trigger antes de que exista su función), debes ejecutar los archivos en un orden específico.

Abre tu terminal en la carpeta raíz del proyecto y ejecuta los scripts uno a uno. Como ejemplo, el primer archivo se lanza así:

```bash
psql -U postgres -f database/00_crear_bd.sql
```

Sigue ese mismo comando para el resto de los archivos respetando estrictamente este orden:

1. `database/01_esquemas_y_tablas/01_esquema.sql`
2. `database/02_logica_y_triggers/02_funciones_utilidad.sql`
3. `database/02_logica_y_triggers/03_triggers_basicos.sql`
4. `database/02_logica_y_triggers/04_triggers_negocio.sql`
5. `database/01_esquemas_y_tablas/05_auditoria.sql`
6. `database/03_componentes_avanzados/06_procedimientos.sql`
7. `database/03_componentes_avanzados/07_reporting.sql`
8. `database/02_logica_y_triggers/08_notify.sql`
9. `database/04_pruebas_y_analisis/09_datos_prueba.sql`
10. `database/04_pruebas_y_analisis/10_consultas_auditoria.sql`

---

## 🛠️ Tecnologías Utilizadas
*   **Motor de base de datos:** PostgreSQL (Versión 15 o superior)
*   **Lenguaje interno:** PL/pgSQL y consultas SQL nativas
*   **Formato de datos:** Documentos JSONB para guardar los cambios de las filas de forma dinámica
*   **Optimización:** Índices normales (B-Tree) para búsquedas rápidas e índices especiales (GIN) para acelerar las consultas sobre los datos en JSON
