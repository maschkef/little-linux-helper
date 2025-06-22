#!/bin/bash
#
# little-linux-helper/lang/es/lib.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# Spanish language strings for lib_common.sh

# Declare MSG_ES as associative array (conditional for module files)
[[ ! -v MSG_ES ]] && declare -A MSG_ES

# Library-specific messages
MSG_ES[LIB_LOG_INITIALIZED]="Registro inicializado. Archivo de registro: %s"
MSG_ES[LIB_LOG_ALREADY_INITIALIZED]="Registro ya inicializado. Usando archivo de registro: %s"
MSG_ES[LIB_LOG_DIR_CREATE_ERROR]="No se pudo crear el directorio de registro: %s"
MSG_ES[LIB_LOG_FILE_CREATE_ERROR]="No se pudo crear el archivo de registro: %s"
MSG_ES[LIB_LOG_FILE_TOUCH_ERROR]="No se pudo tocar/crear el archivo de registro existente: %s"
MSG_ES[LIB_LOG_DIR_NOT_FOUND]="Directorio de registro para %s no encontrado."

# Backup configuration messages
MSG_ES[LIB_BACKUP_CONFIG_LOADED]="Cargando configuración de respaldo desde %s"
MSG_ES[LIB_BACKUP_CONFIG_NOT_FOUND]="No se encontró archivo de configuración de respaldo (%s). Usando valores predeterminados internos."
MSG_ES[LIB_BACKUP_LOG_CONFIGURED]="Archivo de registro de respaldo configurado como: %s"
MSG_ES[LIB_BACKUP_CONFIG_SAVED]="Configuración de respaldo guardada en %s"

# Backup log messages
MSG_ES[LIB_BACKUP_LOG_NOT_DEFINED]="LH_BACKUP_LOG no está definido. El mensaje de respaldo no se puede registrar: %s"
MSG_ES[LIB_BACKUP_LOG_FALLBACK]="(Respaldo-Fallback) %s"
MSG_ES[LIB_BACKUP_LOG_CREATE_ERROR]="No se pudo crear/tocar el archivo de registro de respaldo %s. Directorio: %s"
MSG_ES[LIB_CLEANUP_OLD_BACKUP]="Eliminando respaldo antiguo: %s"

# Root privileges messages
MSG_ES[LIB_ROOT_PRIVILEGES_NEEDED]="Algunas funciones de este script requieren privilegios de root. Por favor ejecute el script con 'sudo'."
MSG_ES[LIB_ROOT_PRIVILEGES_DETECTED]="El script se está ejecutando con privilegios de root."

# Package manager messages
MSG_ES[LIB_PKG_MANAGER_NOT_FOUND]="No se encontró ningún gestor de paquetes compatible."
MSG_ES[LIB_PKG_MANAGER_DETECTED]="Gestor de paquetes detectado: %s"
MSG_ES[LIB_ALT_PKG_MANAGERS_DETECTED]="Gestores de paquetes alternativos detectados: %s"

# Command checking messages
MSG_ES[LIB_PYTHON_NOT_INSTALLED]="Python3 no está instalado, pero es requerido para esta función."
MSG_ES[LIB_PYTHON_INSTALL_ERROR]="Error al instalar Python"
MSG_ES[LIB_PYTHON_SCRIPT_NOT_FOUND]="Script de Python '%s' no encontrado."
MSG_ES[LIB_PROGRAM_NOT_INSTALLED]="El programa '%s' no está instalado."
MSG_ES[LIB_INSTALL_PROMPT]="¿Desea instalar '%s'? (s/n): "
MSG_ES[LIB_INSTALL_ERROR]="Error al instalar %s"
MSG_ES[LIB_INSTALL_SUCCESS]="Instalado exitosamente: %s"
MSG_ES[LIB_INSTALL_FAILED]="No se pudo instalar %s"

# User info messages
MSG_ES[LIB_USER_INFO_CACHED]="Usando información de usuario en caché para %s"
MSG_ES[LIB_USER_INFO_SUCCESS]="Información de usuario para %s determinada exitosamente."
MSG_ES[LIB_USER_INFO_ERROR]="No se pudo determinar la información del usuario. El comando no se puede ejecutar."
MSG_ES[LIB_XDG_RUNTIME_ERROR]="XDG_RUNTIME_DIR para el usuario %s no se pudo determinar o es inválido."
MSG_ES[LIB_COMMAND_EXECUTION]="Ejecutando como usuario %s: %s"

# General warnings
MSG_ES[LIB_WARNING_INITIAL_LOG_DIR]="ADVERTENCIA: No se pudo crear el directorio de registro inicial: %s"

# UI-specific messages
MSG_ES[LIB_UI_INVALID_INPUT]="Entrada inválida. Por favor intente de nuevo."

# Notification messages
MSG_ES[LIB_NOTIFICATION_INCOMPLETE_PARAMS]="lh_send_notification: Parámetros incompletos (type, title, message requeridos)"
MSG_ES[LIB_NOTIFICATION_TRYING_SEND]="Intentando enviar notificación de escritorio: [%s] %s - %s"
MSG_ES[LIB_NOTIFICATION_USER_INFO_FAILED]="No se pudo determinar la información del usuario objetivo, la notificación de escritorio será omitida"
MSG_ES[LIB_NOTIFICATION_NO_VALID_USER]="No se encontró un usuario objetivo válido para la notificación de escritorio (Usuario: '%s')"
MSG_ES[LIB_NOTIFICATION_SENDING_AS_USER]="Enviando notificación como usuario: %s"
MSG_ES[LIB_NOTIFICATION_USING_NOTIFY_SEND]="Usando notify-send para notificación de escritorio"
MSG_ES[LIB_NOTIFICATION_SUCCESS_NOTIFY_SEND]="Notificación de escritorio enviada exitosamente vía notify-send"
MSG_ES[LIB_NOTIFICATION_FAILED_NOTIFY_SEND]="Falló la notificación notify-send"
MSG_ES[LIB_NOTIFICATION_USING_ZENITY]="Usando zenity para notificación de escritorio"
MSG_ES[LIB_NOTIFICATION_SUCCESS_ZENITY]="Notificación de escritorio enviada exitosamente vía zenity"
MSG_ES[LIB_NOTIFICATION_FAILED_ZENITY]="Falló la notificación zenity"
MSG_ES[LIB_NOTIFICATION_USING_KDIALOG]="Usando kdialog para notificación de escritorio"
MSG_ES[LIB_NOTIFICATION_SUCCESS_KDIALOG]="Notificación de escritorio enviada exitosamente vía kdialog"
MSG_ES[LIB_NOTIFICATION_FAILED_KDIALOG]="Falló la notificación kdialog"
MSG_ES[LIB_NOTIFICATION_NO_WORKING_METHOD]="No se encontró un método de notificación de escritorio funcional"
MSG_ES[LIB_NOTIFICATION_CHECK_TOOLS]="Revisar herramientas de notificación disponibles: notify-send, zenity, kdialog"
MSG_ES[LIB_NOTIFICATION_CHECKING_TOOLS]="Verificando herramientas de notificación de escritorio disponibles..."
MSG_ES[LIB_NOTIFICATION_USER_CHECK_FAILED]="No se pudo determinar el usuario objetivo - verificando herramientas como usuario actual"
MSG_ES[LIB_NOTIFICATION_TOOL_AVAILABLE]="✓ %s disponible"
MSG_ES[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]="✗ %s no disponible"
MSG_ES[LIB_NOTIFICATION_TOOLS_AVAILABLE]="Las notificaciones de escritorio están disponibles vía: %s"
MSG_ES[LIB_NOTIFICATION_NO_TOOLS_FOUND]="No se encontraron herramientas de notificación de escritorio."
MSG_ES[LIB_NOTIFICATION_MISSING_TOOLS]="Herramientas faltantes: %s"
MSG_ES[LIB_NOTIFICATION_INSTALL_TOOLS]="¿Desea instalar herramientas de notificación?"
MSG_ES[LIB_NOTIFICATION_AUTO_INSTALL_NOT_AVAILABLE]="Instalación automática para %s no disponible."
MSG_ES[LIB_NOTIFICATION_MANUAL_INSTALL]="Por favor instale manualmente: libnotify-bin/libnotify y zenity"
MSG_ES[LIB_NOTIFICATION_RECHECK_AFTER_INSTALL]="Verificando nuevamente después de la instalación..."
MSG_ES[LIB_NOTIFICATION_TEST_PROMPT]="¿Desea enviar una notificación de prueba?"
MSG_ES[LIB_NOTIFICATION_TEST_MESSAGE]="¡Notificación de prueba exitosa!"

# I18n messages
MSG_ES[LIB_I18N_LANG_DIR_NOT_FOUND]="Directorio de idioma para '%s' no encontrado, usando inglés como respaldo"
MSG_ES[LIB_I18N_DEFAULT_LANG_NOT_FOUND]="Directorio de idioma predeterminado (en) no encontrado en: %s"
MSG_ES[LIB_I18N_UNSUPPORTED_LANG]="Código de idioma no soportado: %s"
MSG_ES[LIB_I18N_LANG_FILE_NOT_FOUND]="Archivo de idioma para módulo '%s' en '%s' no encontrado, intentando inglés"
MSG_ES[LIB_I18N_MODULE_FILE_NOT_FOUND]="Archivo de idioma para módulo '%s' no encontrado: %s"
