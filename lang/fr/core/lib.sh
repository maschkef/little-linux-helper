#!/bin/bash
#
# little-linux-helper/lang/fr/lib.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# French language strings for lib_common.sh

# Declare MSG_FR as associative array (conditional for module files)
[[ ! -v MSG_FR ]] && declare -A MSG_FR

# Library-specific messages
MSG_FR[LIB_LOG_INITIALIZED]="Journalisation initialisée. Fichier journal : %s"
MSG_FR[LIB_LOG_ALREADY_INITIALIZED]="Journalisation déjà initialisée. Utilise le fichier journal : %s"
MSG_FR[LIB_LOG_DIR_CREATE_ERROR]="Impossible de créer le répertoire de journal : %s"
MSG_FR[LIB_LOG_FILE_CREATE_ERROR]="Impossible de créer le fichier journal : %s"
MSG_FR[LIB_LOG_FILE_TOUCH_ERROR]="Impossible de toucher/créer le fichier journal existant : %s"
MSG_FR[LIB_LOG_DIR_NOT_FOUND]="Répertoire de journal pour %s introuvable."

# Backup configuration messages
MSG_FR[LIB_BACKUP_CONFIG_LOADED]="Chargement de la configuration de sauvegarde depuis %s"
MSG_FR[LIB_BACKUP_CONFIG_NOT_FOUND]="Aucun fichier de configuration de sauvegarde (%s) trouvé. Utilisation des valeurs par défaut internes."
MSG_FR[LIB_BACKUP_LOG_CONFIGURED]="Fichier journal de sauvegarde configuré comme : %s"
MSG_FR[LIB_BACKUP_CONFIG_SAVED]="Configuration de sauvegarde enregistrée dans %s"

# Backup log messages
MSG_FR[LIB_BACKUP_LOG_NOT_DEFINED]="LH_BACKUP_LOG n'est pas défini. Le message de sauvegarde ne peut pas être journalisé : %s"
MSG_FR[LIB_BACKUP_LOG_FALLBACK]="(Sauvegarde-Fallback) %s"
MSG_FR[LIB_BACKUP_LOG_CREATE_ERROR]="Impossible de créer/toucher le fichier journal de sauvegarde %s. Répertoire : %s"
MSG_FR[LIB_CLEANUP_OLD_BACKUP]="Suppression de l'ancienne sauvegarde : %s"

# Root privileges messages
MSG_FR[LIB_ROOT_PRIVILEGES_NEEDED]="Certaines fonctions de ce script nécessitent des privilèges root. Veuillez exécuter le script avec 'sudo'."
MSG_FR[LIB_ROOT_PRIVILEGES_DETECTED]="Le script s'exécute avec des privilèges root."

# Package manager messages
MSG_FR[LIB_PKG_MANAGER_NOT_FOUND]="Aucun gestionnaire de paquets pris en charge trouvé."
MSG_FR[LIB_PKG_MANAGER_DETECTED]="Gestionnaire de paquets détecté : %s"
MSG_FR[LIB_ALT_PKG_MANAGERS_DETECTED]="Gestionnaires de paquets alternatifs détectés : %s"

# Command checking messages
MSG_FR[LIB_PYTHON_NOT_INSTALLED]="Python3 n'est pas installé, mais requis pour cette fonction."
MSG_FR[LIB_PYTHON_INSTALL_ERROR]="Erreur lors de l'installation de Python"
MSG_FR[LIB_PYTHON_SCRIPT_NOT_FOUND]="Script Python '%s' introuvable."
MSG_FR[LIB_PROGRAM_NOT_INSTALLED]="Le programme '%s' n'est pas installé."
MSG_FR[LIB_INSTALL_PROMPT]="Voulez-vous installer '%s' ? (o/n) : "
MSG_FR[LIB_INSTALL_ERROR]="Erreur lors de l'installation de %s"
MSG_FR[LIB_INSTALL_SUCCESS]="Installé avec succès : %s"
MSG_FR[LIB_INSTALL_FAILED]="Impossible d'installer %s"

# User info messages
MSG_FR[LIB_USER_INFO_CACHED]="Utilisation des informations utilisateur mises en cache pour %s"
MSG_FR[LIB_USER_INFO_SUCCESS]="Informations utilisateur pour %s déterminées avec succès."
MSG_FR[LIB_USER_INFO_ERROR]="Impossible de déterminer les informations utilisateur. La commande ne peut pas être exécutée."
MSG_FR[LIB_XDG_RUNTIME_ERROR]="XDG_RUNTIME_DIR pour l'utilisateur %s n'a pas pu être déterminé ou est invalide."
MSG_FR[LIB_COMMAND_EXECUTION]="Exécution en tant qu'utilisateur %s : %s"

# General warnings
MSG_FR[LIB_WARNING_INITIAL_LOG_DIR]="AVERTISSEMENT : Impossible de créer le répertoire de journal initial : %s"

# UI-specific messages
MSG_FR[LIB_UI_INVALID_INPUT]="Entrée invalide. Veuillez réessayer."

# Session registry messages
MSG_FR[LIB_SESSION_ACTIVITY_INITIALIZING]="Initialisation en cours"
MSG_FR[LIB_SESSION_ACTIVITY_MENU]="Affichage du menu"
MSG_FR[LIB_SESSION_ACTIVITY_WAITING]="En attente d'une entrée utilisateur"
MSG_FR[LIB_SESSION_ACTIVITY_SECTION]="Traitement : %s"
MSG_FR[LIB_SESSION_ACTIVITY_ACTION]="Exécution : %s"
MSG_FR[LIB_SESSION_ACTIVITY_PREP]="Préparation : %s"
MSG_FR[LIB_SESSION_ACTIVITY_BACKUP]="Sauvegarde : %s"
MSG_FR[LIB_SESSION_ACTIVITY_RESTORE]="Restauration : %s"
MSG_FR[LIB_SESSION_ACTIVITY_CLEANUP]="Nettoyage : %s"
MSG_FR[LIB_SESSION_LOCK_TIMEOUT]="Registre des sessions occupé, mise à jour ignorée."
MSG_FR[LIB_SESSION_REGISTERED]="Session démarrée : %s (%s)"
MSG_FR[LIB_SESSION_UPDATED]="Session mise à jour : %s -> %s"
MSG_FR[LIB_SESSION_UNREGISTERED]="Session terminée : %s"
MSG_FR[LIB_SESSION_DEBUG_NONE]="Aucune autre session active (module : %s)"
MSG_FR[LIB_SESSION_DEBUG_LIST_HEADER]="Sessions actives avant de démarrer %s (%d au total) :"
MSG_FR[LIB_SESSION_DEBUG_ENTRY]="%s [%s] %s (%s)"

# Notification messages
MSG_FR[LIB_NOTIFICATION_INCOMPLETE_PARAMS]="lh_send_notification : Paramètres incomplets (type, title, message requis)"
MSG_FR[LIB_NOTIFICATION_TRYING_SEND]="Tentative d'envoi de notification de bureau : [%s] %s - %s"
MSG_FR[LIB_NOTIFICATION_USER_INFO_FAILED]="Impossible de déterminer les informations de l'utilisateur cible, notification de bureau ignorée"
MSG_FR[LIB_NOTIFICATION_NO_VALID_USER]="Aucun utilisateur cible valide trouvé pour la notification de bureau (Utilisateur : '%s')"
MSG_FR[LIB_NOTIFICATION_SENDING_AS_USER]="Envoi de notification en tant qu'utilisateur : %s"
MSG_FR[LIB_NOTIFICATION_USING_NOTIFY_SEND]="Utilisation de notify-send pour notification de bureau"
MSG_FR[LIB_NOTIFICATION_SUCCESS_NOTIFY_SEND]="Notification de bureau envoyée avec succès via notify-send"
MSG_FR[LIB_NOTIFICATION_FAILED_NOTIFY_SEND]="Échec de la notification notify-send"
MSG_FR[LIB_NOTIFICATION_USING_ZENITY]="Utilisation de zenity pour notification de bureau"
MSG_FR[LIB_NOTIFICATION_SUCCESS_ZENITY]="Notification de bureau envoyée avec succès via zenity"
MSG_FR[LIB_NOTIFICATION_FAILED_ZENITY]="Échec de la notification zenity"
MSG_FR[LIB_NOTIFICATION_USING_KDIALOG]="Utilisation de kdialog pour notification de bureau"
MSG_FR[LIB_NOTIFICATION_SUCCESS_KDIALOG]="Notification de bureau envoyée avec succès via kdialog"
MSG_FR[LIB_NOTIFICATION_FAILED_KDIALOG]="Échec de la notification kdialog"
MSG_FR[LIB_NOTIFICATION_NO_WORKING_METHOD]="Aucune méthode de notification de bureau fonctionnelle trouvée"
MSG_FR[LIB_NOTIFICATION_CHECK_TOOLS]="Vérifier les outils de notification disponibles : notify-send, zenity, kdialog"
MSG_FR[LIB_NOTIFICATION_CHECKING_TOOLS]="Vérification des outils de notification de bureau disponibles..."
MSG_FR[LIB_NOTIFICATION_USER_CHECK_FAILED]="Impossible de déterminer l'utilisateur cible - vérification des outils en tant qu'utilisateur actuel"
MSG_FR[LIB_NOTIFICATION_TOOL_AVAILABLE]="✓ %s disponible"
MSG_FR[LIB_NOTIFICATION_TOOL_NOT_AVAILABLE]="✗ %s non disponible"
MSG_FR[LIB_NOTIFICATION_TOOLS_AVAILABLE]="Les notifications de bureau sont disponibles via : %s"
MSG_FR[LIB_NOTIFICATION_NO_TOOLS_FOUND]="Aucun outil de notification de bureau trouvé."
MSG_FR[LIB_NOTIFICATION_MISSING_TOOLS]="Outils manquants : %s"
MSG_FR[LIB_NOTIFICATION_INSTALL_TOOLS]="Voulez-vous installer les outils de notification ?"
MSG_FR[LIB_NOTIFICATION_AUTO_INSTALL_NOT_AVAILABLE]="Installation automatique pour %s non disponible."
MSG_FR[LIB_NOTIFICATION_MANUAL_INSTALL]="Veuillez installer manuellement : libnotify-bin/libnotify et zenity"
MSG_FR[LIB_NOTIFICATION_RECHECK_AFTER_INSTALL]="Vérification à nouveau après l'installation..."
MSG_FR[LIB_NOTIFICATION_TEST_PROMPT]="Voulez-vous envoyer une notification de test ?"

# I18n messages
MSG_FR[LIB_I18N_LANG_DIR_NOT_FOUND]="Répertoire de langue pour '%s' introuvable, utilisation de l'anglais par défaut"
MSG_FR[LIB_I18N_DEFAULT_LANG_NOT_FOUND]="Répertoire de langue par défaut (en) introuvable à : %s"
MSG_FR[LIB_I18N_UNSUPPORTED_LANG]="Code de langue non pris en charge : %s"
MSG_FR[LIB_I18N_LANG_FILE_NOT_FOUND]="Fichier de langue pour le module '%s' en '%s' introuvable, tentative en anglais"
MSG_FR[LIB_I18N_MODULE_FILE_NOT_FOUND]="Fichier de langue pour le module '%s' introuvable : %s"
