<#
.SYNOPSIS
    Script de automatización para la gestión de tareas de dbsentinel en PostgreSQL 17/18.
    Diseñado para ejecución desatendida en Windows Task Scheduler.
#>

# 1. Definición de variables de entorno seguras para PostgreSQL
$env:PGPASSWORD = "tu_contraseña"
$Database = "dbsentinel"
$User = "postgres" 
$PsqlPath = "C:\PostgreSQL\17\bin\psql.exe" # Modificar a otra si aplica
$LogFile = "$PSScriptRoot\resultado_log.txt"

# 2. Comando SQL a ejecutar
$Query = "CALL app.generar_tareas_pagos_pendientes();"

Write-Host "Iniciando proceso por lotes de HelpDesk..." -ForegroundColor Cyan

# 3. Bloque Try-Catch para capturar fallos críticos de conexión o base de datos
try {
    # 1. Ejecutamos el procedimiento almacenado (Dejará la palabra CALL en el log)
    & $PsqlPath -U $User -d $Database -c $Query *>> $LogFile
    
    # 2. AGREGA ESTA LÍNEA: Consulta automática para ver los resultados en el log
    $CheckQuery = "SELECT tarea_id, titulo, prioridad, estado FROM app.tareas_pendientes ORDER BY creado_en DESC LIMIT 5;"
    "--- ESTADO ACTUAL DE LAS ÚLTIMAS TAREAS GENERADAS ---" | Out-File -FilePath $LogFile -Append
    & $PsqlPath -U $User -d $Database -c $CheckQuery *>> $LogFile
    
    Write-Host "Procedimiento ejecutado con éxito y resultados volcados al Log." -ForegroundColor Green
}

catch {
    Write-Warning "Error crítico durante la ejecución del script: $_"
    "ERROR CRÍTICO [$([DateTime]::Now)]: $_" | Out-File -FilePath $LogFile -Append
}
finally {
    # Limpieza obligatoria de la contraseña en la memoria de la sesión por seguridad
    Remove-Item Env:\PGPASSWORD
}
