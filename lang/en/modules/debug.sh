#!/bin/bash
#
# lang/en/modules/debug.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: Apache-2.0
#
# English language strings for debug module

[[ ! -v MSG_EN ]] && declare -A MSG_EN

MSG_EN[DEBUG_MODULE_NAME]="System Debug Report"
MSG_EN[DEBUG_MODULE_DESC]="Generates a detailed system report for troubleshooting."
MSG_EN[DEBUG_SECTION_BASIC]="Basic System Information"
MSG_EN[DEBUG_SECTION_HARDWARE]="Hardware Resources"
MSG_EN[DEBUG_SECTION_LOGS]="System and Application Logs"
MSG_EN[DEBUG_STARTING]="Generating debug report at: %s"
MSG_EN[DEBUG_COMPLETE]="Debug report generation finished successfully."
MSG_EN[DEBUG_REPORT_CREATED]="Debug Report Ready"
MSG_EN[DEBUG_REVIEW_HINT]="Please review the file before sharing it."
MSG_EN[DEBUG_VIEW_NOW]="Do you want to view the report now?"
