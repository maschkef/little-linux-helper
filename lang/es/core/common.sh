#!/bin/bash
#
# little-linux-helper/lang/es/common.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# Spanish common language strings

# Declare MSG_ES as associative array
# shellcheck disable=SC2034  # consumed by lib/lib_i18n.sh when populating MSG
declare -A MSG_ES

# General UI elements
MSG_ES[YES]="Sí"
MSG_ES[NO]="No"
MSG_ES[CANCEL]="Cancelar"
MSG_ES[OK]="OK"
MSG_ES[ERROR]="Error"
MSG_ES[WARNING]="Advertencia"
MSG_ES[INFO]="Información"
MSG_ES[SUCCESS]="Éxito"
MSG_ES[FAILED]="Falló"
MSG_ES[LOADING]="Cargando..."
MSG_ES[PLEASE_WAIT]="Por favor espere..."
MSG_ES[DONE]="Hecho"
MSG_ES[CONTINUE]="Continuar"
MSG_ES[BACK]="Atrás"
MSG_ES[EXIT]="Salir"
MSG_ES[QUIT]="Cerrar"

# Time and date
MSG_ES[TODAY]="Hoy"
MSG_ES[YESTERDAY]="Ayer"
MSG_ES[TOMORROW]="Mañana"
MSG_ES[NEVER]="Nunca"
MSG_ES[UNKNOWN]="Desconocido"

# File operations
MSG_ES[FILE]="Archivo"
MSG_ES[DIRECTORY]="Directorio"
MSG_ES[SIZE]="Tamaño"
MSG_ES[CREATED]="Creado"
MSG_ES[MODIFIED]="Modificado"
MSG_ES[PERMISSIONS]="Permisos"

# System states
MSG_ES[ONLINE]="En línea"
MSG_ES[OFFLINE]="Fuera de línea"
MSG_ES[ACTIVE]="Activo"
MSG_ES[INACTIVE]="Inactivo"
MSG_ES[ENABLED]="Habilitado"
MSG_ES[DISABLED]="Deshabilitado"
MSG_ES[RUNNING]="Ejecutándose"
MSG_ES[STOPPED]="Detenido"

# Common actions
MSG_ES[START]="Iniciar"
MSG_ES[STOP]="Detener"
MSG_ES[RESTART]="Reiniciar"
MSG_ES[INSTALL]="Instalar"
MSG_ES[UNINSTALL]="Desinstalar"
MSG_ES[UPDATE]="Actualizar"
MSG_ES[UPGRADE]="Actualizar versión"
MSG_ES[DOWNLOAD]="Descargar"
MSG_ES[UPLOAD]="Subir"
MSG_ES[SAVE]="Guardar"
MSG_ES[LOAD]="Cargar"
MSG_ES[DELETE]="Eliminar"
MSG_ES[REMOVE]="Remover"
MSG_ES[CREATE]="Crear"
MSG_ES[EDIT]="Editar"
MSG_ES[VIEW]="Ver"
MSG_ES[SEARCH]="Buscar"
MSG_ES[FIND]="Encontrar"
MSG_ES[COPY]="Copiar"
MSG_ES[MOVE]="Mover"
MSG_ES[RENAME]="Renombrar"

# Common questions and prompts
MSG_ES[CONFIRM_ACTION]="¿Desea continuar?"
MSG_ES[ARE_YOU_SURE]="¿Está seguro?"
MSG_ES[PRESS_KEY_CONTINUE]="Presione cualquier tecla para continuar..."
MSG_ES[PRESS_ENTER]="Presione Enter..."
MSG_ES[CHOOSE_OPTION]="Elija una opción:"
MSG_ES[INVALID_SELECTION]="Selección inválida. Por favor intente de nuevo."
MSG_ES[ENTER_VALUE]="Ingrese un valor:"
MSG_ES[ENTER_PATH]="Ingrese una ruta:"
MSG_ES[ENTER_FILENAME]="Ingrese un nombre de archivo:"

# Error messages
MSG_ES[ERROR_GENERAL]="Ocurrió un error."
MSG_ES[ERROR_FILE_NOT_FOUND]="Archivo no encontrado."
MSG_ES[ERROR_PERMISSION_DENIED]="Permiso denegado."
MSG_ES[ERROR_COMMAND_NOT_FOUND]="Comando no encontrado."
MSG_ES[ERROR_OPERATION_FAILED]="Operación fallida."
MSG_ES[ERROR_INVALID_INPUT]="Entrada inválida."
MSG_ES[ERROR_NETWORK]="Error de red."
MSG_ES[ERROR_TIMEOUT]="Tiempo de espera agotado."

# Success messages
MSG_ES[SUCCESS_OPERATION_COMPLETED]="Operación completada exitosamente."
MSG_ES[SUCCESS_FILE_SAVED]="Archivo guardado."
MSG_ES[SUCCESS_INSTALLED]="Instalado exitosamente."
MSG_ES[SUCCESS_UPDATED]="Actualizado exitosamente."
MSG_ES[SUCCESS_REMOVED]="Removido exitosamente."

# Units
MSG_ES[BYTES]="Bytes"
MSG_ES[KB]="KB"
MSG_ES[MB]="MB"
MSG_ES[GB]="GB"
MSG_ES[TB]="TB"
MSG_ES[PERCENT]="Porcentaje"
MSG_ES[SECONDS]="Segundos"
MSG_ES[MINUTES]="Minutos"
MSG_ES[HOURS]="Horas"
MSG_ES[DAYS]="Días"
