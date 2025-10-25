#!/bin/bash
#
# little-linux-helper/lang/en/energy.sh
# Copyright (c) 2025 maschkef
# SPDX-License-Identifier: MIT
#
# English language strings for energy management module

# Conditional declaration for module files
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Menu items and headers
MSG_EN[ENERGY_MENU_TITLE]="Energy Management"
MSG_EN[ENERGY_MENU_DISABLE_SLEEP]="Disable Sleep/Hibernate Temporarily"
MSG_EN[ENERGY_MENU_CPU_GOVERNOR]="CPU Governor Management"
MSG_EN[ENERGY_MENU_SCREEN_BRIGHTNESS]="Screen Brightness Control"
MSG_EN[ENERGY_MENU_POWER_STATS]="Power Statistics & Information"

# Headers
MSG_EN[ENERGY_HEADER_DISABLE_SLEEP]="Disable Sleep/Hibernate"
MSG_EN[ENERGY_HEADER_SLEEP_STATUS]="Sleep Inhibit Status"
MSG_EN[ENERGY_HEADER_RESTORE_SLEEP]="Restore Sleep Functionality"
MSG_EN[ENERGY_HEADER_CPU_GOVERNOR]="CPU Governor Management"
MSG_EN[ENERGY_HEADER_SCREEN_BRIGHTNESS]="Screen Brightness Control"
MSG_EN[ENERGY_HEADER_POWER_STATS]="Power Statistics & Information"

# Sleep management
MSG_EN[ENERGY_SLEEP_OPTIONS]="Sleep disable options:"
MSG_EN[ENERGY_SLEEP_UNTIL_SHUTDOWN]="Disable until next manual shutdown"
MSG_EN[ENERGY_SLEEP_FOR_TIME]="Disable for specific time"
MSG_EN[ENERGY_SLEEP_SHOW_STATUS]="Show current sleep inhibit status"
MSG_EN[ENERGY_SLEEP_RESTORE]="Restore sleep functionality"

MSG_EN[ENERGY_TIME_OPTIONS]="Time duration options:"
MSG_EN[ENERGY_TIME_30MIN]="30 minutes"
MSG_EN[ENERGY_TIME_1HOUR]="1 hour"
MSG_EN[ENERGY_TIME_2HOURS]="2 hours"
MSG_EN[ENERGY_TIME_4HOURS]="4 hours"
MSG_EN[ENERGY_TIME_CUSTOM]="Custom time (in minutes)"

MSG_EN[ENERGY_UNIT_MINUTES]="minutes"
MSG_EN[ENERGY_UNIT_HOUR]="hour"
MSG_EN[ENERGY_UNIT_HOURS]="hours"

MSG_EN[ENERGY_ASK_CUSTOM_MINUTES]="Enter time in minutes:"
MSG_EN[ENERGY_ERROR_INVALID_NUMBER]="Please enter a valid number."
MSG_EN[ENERGY_ERROR_NO_TIME_SPECIFIED]="No time specified."

MSG_EN[ENERGY_CONFIRM_DISABLE_SLEEP_PERMANENT]="Do you want to disable sleep/hibernate until the next manual shutdown?"
MSG_EN[ENERGY_CONFIRM_DISABLE_SLEEP_TIME]="Do you want to disable sleep/hibernate for %s?"
MSG_EN[ENERGY_CONFIRM_RESTORE_SLEEP]="Do you want to restore sleep/hibernate functionality?"

MSG_EN[ENERGY_SUCCESS_SLEEP_DISABLED_PERMANENT]="Sleep/hibernate disabled until next manual shutdown."
MSG_EN[ENERGY_SUCCESS_SLEEP_DISABLED_TIME]="Sleep/hibernate disabled for %s."
MSG_EN[ENERGY_SUCCESS_SLEEP_RESTORED]="Sleep/hibernate functionality restored."

MSG_EN[ENERGY_INFO_RESTORE_SLEEP]="To restore sleep functionality, use option 4 in this menu."
MSG_EN[ENERGY_INFO_NO_ACTIVE_INHIBIT]="No active sleep inhibit found."
MSG_EN[ENERGY_INFO_NO_TEMP_INHIBIT]="No temporary sleep inhibit by Little Linux Helper found."
MSG_EN[ENERGY_BACKUP_SLEEP_NOTE_TITLE]="Note: Backup operations are currently preventing sleep independently."
MSG_EN[ENERGY_BACKUP_SLEEP_NOTE_HINT]="Your energy setting will work alongside the current backup operation."
MSG_EN[ENERGY_BACKUP_SLEEP_NOTE_HINT_TIMER]="Your %s timer will run alongside any backup operations."

MSG_EN[ENERGY_STATUS_CURRENT_INHIBITS]="Current sleep inhibits:"
MSG_EN[ENERGY_STATUS_NO_INHIBITS]="No active sleep inhibits found."
MSG_EN[ENERGY_STATUS_OUR_INHIBIT_ACTIVE]="Little Linux Helper sleep inhibit active (PID: %s)"
MSG_EN[ENERGY_STATUS_OUR_INHIBIT_INACTIVE]="Little Linux Helper sleep inhibit not active."
MSG_EN[ENERGY_STATUS_OUR_INHIBIT_NONE]="No Little Linux Helper sleep inhibit found."

MSG_EN[ENERGY_INHIBIT_REASON]="Temporary sleep disable by user request"
MSG_EN[ENERGY_INHIBIT_REASON_TIME]="Temporary sleep disable for %s by user request"

MSG_EN[ENERGY_ERROR_NO_SYSTEMD_INHIBIT]="systemd-inhibit command not found. Cannot manage sleep settings."

# CPU Governor
MSG_EN[ENERGY_CPU_CURRENT_GOVERNOR]="Current CPU frequency governor:"
MSG_EN[ENERGY_CPU_AVAILABLE_GOVERNORS]="Available governors:"
MSG_EN[ENERGY_CPU_NO_AVAILABLE_GOVERNORS]="Available governors information not found."
MSG_EN[ENERGY_CPU_NO_CPUFREQ]="CPU frequency scaling not available on this system."
MSG_EN[ENERGY_CPU_GOVERNOR_CURRENT]="Current governor: %s"

MSG_EN[ENERGY_CPU_GOVERNOR_OPTIONS]="CPU governor options:"
MSG_EN[ENERGY_CPU_SET_PERFORMANCE]="Performance (maximum performance)"
MSG_EN[ENERGY_CPU_SET_POWERSAVE]="Powersave (minimum power consumption)"
MSG_EN[ENERGY_CPU_SET_ONDEMAND]="On-demand (dynamic scaling)"
MSG_EN[ENERGY_CPU_SET_CONSERVATIVE]="Conservative (gradual scaling)"
MSG_EN[ENERGY_CPU_SET_CUSTOM]="Custom governor"

MSG_EN[ENERGY_ASK_CUSTOM_GOVERNOR]="Enter governor name:"
MSG_EN[ENERGY_CONFIRM_SET_GOVERNOR]="Do you want to set CPU governor to '%s'?"

MSG_EN[ENERGY_SUCCESS_GOVERNOR_SET]="CPU governor set to '%s'."
MSG_EN[ENERGY_ERROR_GOVERNOR_SET_FAILED]="Failed to set CPU governor to '%s'."

MSG_EN[ENERGY_ERROR_NO_CPUPOWER]="cpupower command not found. Please install cpupower utilities."

# Screen Brightness
MSG_EN[ENERGY_BRIGHTNESS_CURRENT]="Current screen brightness:"
MSG_EN[ENERGY_BRIGHTNESS_INFO_FAILED]="Failed to get brightness information."
MSG_EN[ENERGY_BRIGHTNESS_CURRENT_VALUE]="Current brightness: %s%%"
MSG_EN[ENERGY_BRIGHTNESS_SYSFS_INFO]="Current: %s, Maximum: %s (%s%%)"

MSG_EN[ENERGY_BRIGHTNESS_OPTIONS]="Brightness options:"
MSG_EN[ENERGY_BRIGHTNESS_SET_25]="Set to 25%%"
MSG_EN[ENERGY_BRIGHTNESS_SET_50]="Set to 50%%"
MSG_EN[ENERGY_BRIGHTNESS_SET_75]="Set to 75%%"
MSG_EN[ENERGY_BRIGHTNESS_SET_100]="Set to 100%%"
MSG_EN[ENERGY_BRIGHTNESS_SET_CUSTOM]="Custom percentage"

MSG_EN[ENERGY_ASK_BRIGHTNESS_PERCENT]="Enter brightness percentage (1-100):"
MSG_EN[ENERGY_ERROR_INVALID_BRIGHTNESS]="Please enter a valid number between 1 and 100."
MSG_EN[ENERGY_ERROR_BRIGHTNESS_RANGE]="Brightness value must be between 1 and 100."

MSG_EN[ENERGY_CONFIRM_SET_BRIGHTNESS]="Do you want to set screen brightness to %s%%?"

MSG_EN[ENERGY_SUCCESS_BRIGHTNESS_SET]="Screen brightness set to %s%%."
MSG_EN[ENERGY_ERROR_BRIGHTNESS_SET_FAILED]="Failed to set screen brightness to %s%%."

MSG_EN[ENERGY_ERROR_NO_BRIGHTNESS_CONTROL]="No brightness control tools found."
MSG_EN[ENERGY_INFO_BRIGHTNESS_TOOLS]="Please install: brightnessctl, xbacklight, or ensure backlight support is available."

# Power Statistics
MSG_EN[ENERGY_STATS_BATTERY_INFO]="Battery Information:"
MSG_EN[ENERGY_STATS_BATTERY_DEVICE]="Battery Device: %s"
MSG_EN[ENERGY_STATS_BATTERY_CAPACITY]="Capacity"
MSG_EN[ENERGY_STATS_BATTERY_STATUS]="Status"
MSG_EN[ENERGY_STATS_BATTERY_ENERGY]="Energy"
MSG_EN[ENERGY_STATS_NO_BATTERY]="No battery devices found."
MSG_EN[ENERGY_STATS_NO_POWER_SUPPLY]="Power supply information not available."

MSG_EN[ENERGY_STATS_AC_ADAPTER]="AC Adapter Status:"
MSG_EN[ENERGY_STATS_AC_CONNECTED]="AC Adapter '%s' is connected"
MSG_EN[ENERGY_STATS_AC_DISCONNECTED]="AC Adapter '%s' is disconnected"
MSG_EN[ENERGY_STATS_NO_AC_ADAPTER]="No AC adapter information found."

MSG_EN[ENERGY_STATS_THERMAL_ZONES]="Thermal Zones (Temperature):"
MSG_EN[ENERGY_STATS_NO_THERMAL]="Thermal zone information not available."

# Notifications
MSG_EN[ENERGY_NOTIFICATION_TITLE]="Energy Management"
MSG_EN[ENERGY_NOTIFICATION_SLEEP_DISABLED]="Sleep/hibernate disabled"
MSG_EN[ENERGY_NOTIFICATION_SLEEP_DISABLED_TIME]="Sleep/hibernate disabled for %s"
MSG_EN[ENERGY_NOTIFICATION_SLEEP_RESTORED]="Sleep/hibernate restored"
MSG_EN[ENERGY_NOTIFICATION_GOVERNOR_SET]="CPU governor set to %s"
MSG_EN[ENERGY_NOTIFICATION_BRIGHTNESS_SET]="Screen brightness set to %s%%"

# Log messages
MSG_EN[ENERGY_LOG_DISABLE_SLEEP_START]="Starting sleep disable functionality"
MSG_EN[ENERGY_LOG_DISABLING_SLEEP_PERMANENT]="Disabling sleep/hibernate until shutdown"
MSG_EN[ENERGY_LOG_DISABLING_SLEEP_TIME]="Disabling sleep/hibernate for %s"
MSG_EN[ENERGY_LOG_RESTORING_SLEEP]="Restoring sleep functionality, killing process %s"
MSG_EN[ENERGY_LOG_SLEEP_DISABLED_PID]="Sleep disabled with inhibit process PID: %s"
MSG_EN[ENERGY_LOG_SLEEP_DISABLED_TIME_PID]="Sleep disabled for %s with inhibit process PID: %s"
MSG_EN[ENERGY_LOG_SLEEP_RESTORED]="Sleep functionality restored"
MSG_EN[ENERGY_LOG_SETTING_GOVERNOR]="Setting CPU governor to %s"
MSG_EN[ENERGY_LOG_GOVERNOR_SET_SUCCESS]="CPU governor successfully set to %s"
MSG_EN[ENERGY_LOG_GOVERNOR_SET_FAILED]="Failed to set CPU governor to %s"
MSG_EN[ENERGY_LOG_SETTING_BRIGHTNESS]="Setting screen brightness to %s%%"
MSG_EN[ENERGY_LOG_BRIGHTNESS_SET_SUCCESS]="Screen brightness successfully set to %s%%"
MSG_EN[ENERGY_LOG_BRIGHTNESS_SET_FAILED]="Failed to set screen brightness to %s%%"
MSG_EN[ENERGY_LOG_MODULE_EXIT]="Exiting energy management module"

# Quick Actions
MSG_EN[ENERGY_QUICK_ACTIONS_TITLE]="Quick Actions:"
MSG_EN[ENERGY_QUICK_ACTION_RESTORE]="Restore sleep functionality (stop energy inhibit)"
MSG_EN[ENERGY_QUICK_ACTION_RETURN]="Return to energy menu"
MSG_EN[ENERGY_QUICK_CHOOSE_ACTION]="Choose action (r/Enter):"

# Additional missing keys from analysis
MSG_EN[ENERGY_LOG_SLEEP_DISABLED]="Sleep disabled successfully"
MSG_EN[ENERGY_LOG_SLEEP_DISABLED_TIME]="Sleep disabled for %s minutes"
MSG_EN[ENERGY_LOG_SLEEP_DISABLED_PID]="Sleep disabled with inhibit process PID: %s"
MSG_EN[ENERGY_LOG_SLEEP_DISABLED_TIME_PID]="Sleep disabled for %s with inhibit process PID: %s"
MSG_EN[ENERGY_STATUS_OUR_INHIBIT_NONE]="No Little Linux Helper sleep inhibit found."
