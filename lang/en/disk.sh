#!/bin/bash
#
# little-linux-helper/lang/en/disk.sh
# Copyright (c) 2025 wuldorf
# SPDX-License-Identifier: MIT
#
# English language strings for disk module

# Conditional declaration for module files
[[ ! -v MSG_EN ]] && declare -A MSG_EN

# Menu items and headers
MSG_EN[DISK_MENU_TITLE]="Disk Tools"
MSG_EN[DISK_MENU_MOUNTED]="Overview of mounted drives"
MSG_EN[DISK_MENU_SMART]="Read S.M.A.R.T. values"
MSG_EN[DISK_MENU_FILE_ACCESS]="Check file access"
MSG_EN[DISK_MENU_USAGE]="Check disk usage"
MSG_EN[DISK_MENU_SPEED_TEST]="Test disk speed"
MSG_EN[DISK_MENU_FILESYSTEM]="Check filesystem"
MSG_EN[DISK_MENU_HEALTH]="Check disk health status"
MSG_EN[DISK_MENU_LARGEST_FILES]="Show largest files"
MSG_EN[DISK_MENU_BACK]="Back to main menu"

# Headers
MSG_EN[DISK_HEADER_MOUNTED]="Mounted Drives"
MSG_EN[DISK_HEADER_SMART]="S.M.A.R.T. Values"
MSG_EN[DISK_HEADER_FILE_ACCESS]="Check File Access"
MSG_EN[DISK_HEADER_USAGE]="Check Disk Usage"
MSG_EN[DISK_HEADER_SPEED_TEST]="Test Disk Speed"
MSG_EN[DISK_HEADER_FILESYSTEM]="Check Filesystem"
MSG_EN[DISK_HEADER_HEALTH]="Check Disk Health Status"
MSG_EN[DISK_HEADER_LARGEST_FILES]="Show Largest Files"

# Mounted drives
MSG_EN[DISK_MOUNTED_OVERVIEW]="Overview of currently mounted drives (df):"
MSG_EN[DISK_MOUNTED_BLOCKDEVICES]="All block devices with filesystem details (lsblk):"

# S.M.A.R.T. related
MSG_EN[DISK_SMART_SCANNING]="Scanning for available drives..."
MSG_EN[DISK_SMART_NO_DRIVES]="No drives found. Trying direct search..."
MSG_EN[DISK_SMART_NO_DRIVES_FOUND]="No hard drives found or 'smartctl' could not detect any devices."
MSG_EN[DISK_SMART_FOUND_DRIVES]="Found drives:"
MSG_EN[DISK_SMART_CHECK_ALL]="Check all drives"
MSG_EN[DISK_SMART_SELECT_DRIVE]="Please select a drive (1-%d):"
MSG_EN[DISK_SMART_VALUES_FOR]="=== S.M.A.R.T. values for %s ==="

# File access
MSG_EN[DISK_ACCESS_ENTER_PATH]="Enter the path of the folder"
MSG_EN[DISK_ACCESS_PATH_NOT_EXIST]="The specified path does not exist or is not a directory."
MSG_EN[DISK_ACCESS_CHECKING]="Checking which processes are accessing the folder %s..."

# Disk usage
MSG_EN[DISK_USAGE_OVERVIEW]="Overview of storage usage by filesystems:"
MSG_EN[DISK_USAGE_NCDU_START]="Would you like to start the interactive disk analysis with ncdu?"
MSG_EN[DISK_USAGE_NCDU_INSTALL]="Would you like to install the interactive disk analysis tool 'ncdu'?"
MSG_EN[DISK_USAGE_ANALYZE_PATH]="Enter the path to analyze (e.g. /home or /)"
MSG_EN[DISK_USAGE_ALTERNATIVE]="Alternatively, the largest files can also be displayed with du/find."
MSG_EN[DISK_USAGE_SHOW_LARGEST]="Would you like to show the largest files in a specific directory?"

# Speed test
MSG_EN[DISK_SPEED_AVAILABLE_DEVICES]="Available block devices:"
MSG_EN[DISK_SPEED_ENTER_DRIVE]="Enter the drive to test (e.g. /dev/sda)"
MSG_EN[DISK_SPEED_NOT_BLOCK_DEVICE]="The specified device does not exist or is not a block device."
MSG_EN[DISK_SPEED_INFO_NOTE]="Note: This test is only a basic read test. For comprehensive tests we recommend tools like 'fio' or 'dd'."
MSG_EN[DISK_SPEED_TESTING]="Testing disk speed for %s..."
MSG_EN[DISK_SPEED_EXTENDED_TEST]="Would you like to perform an extended write test with 'dd'? (May take some time)"
MSG_EN[DISK_SPEED_WRITE_WARNING]="Warning: This test writes temporary data to the hard drive. Make sure there is enough free space available."
MSG_EN[DISK_SPEED_CONFIRM_WRITE]="Are you sure you want to continue?"
MSG_EN[DISK_SPEED_WRITE_TEST]="Performing write test with dd (512 MB)..."
MSG_EN[DISK_SPEED_CLEANUP]="Cleaning up test file..."

# Filesystem check
MSG_EN[DISK_FSCK_AVAILABLE_PARTITIONS]="Available partitions:"
MSG_EN[DISK_FSCK_WARNING_UNMOUNTED]="WARNING: Filesystem checks should only be performed on unmounted partitions!"
MSG_EN[DISK_FSCK_WARNING_LIVECD]="         It is recommended to perform this check from a Live CD or in recovery mode."
MSG_EN[DISK_FSCK_CONTINUE_ANYWAY]="Would you like to continue anyway?"
MSG_EN[DISK_FSCK_ENTER_PARTITION]="Enter the partition to check (e.g. /dev/sda1)"
MSG_EN[DISK_FSCK_NOT_BLOCK_DEVICE]="The specified partition does not exist or is not a block device."
MSG_EN[DISK_FSCK_PARTITION_MOUNTED]="ERROR: Partition %s is currently mounted! Please unmount it first."
MSG_EN[DISK_FSCK_UNMOUNT_INFO]="To unmount a partition: sudo umount %s"
MSG_EN[DISK_FSCK_AUTO_UNMOUNT]="Would you like to try to unmount the partition automatically?"
MSG_EN[DISK_FSCK_UNMOUNT_SUCCESS]="Partition successfully unmounted. Continuing with check."
MSG_EN[DISK_FSCK_UNMOUNT_FAILED]="Could not unmount partition. Aborting check."
MSG_EN[DISK_FSCK_CHECK_ABORTED]="Check aborted."
MSG_EN[DISK_FSCK_OPTIONS_PROMPT]="Would you like to run fsck with special options?"
MSG_EN[DISK_FSCK_OPTION_CHECK_ONLY]="Check only without repair (-n)"
MSG_EN[DISK_FSCK_OPTION_AUTO_SIMPLE]="Automatic repair, simple problems (-a)"
MSG_EN[DISK_FSCK_OPTION_INTERACTIVE]="Interactive repair, ask for each problem (-r)"
MSG_EN[DISK_FSCK_OPTION_AUTO_COMPLEX]="Automatic repair, complex problems (-y)"
MSG_EN[DISK_FSCK_OPTION_DEFAULT]="No options, default"
MSG_EN[DISK_FSCK_SELECT_OPTION]="Select an option (1-5):"
MSG_EN[DISK_FSCK_INVALID_DEFAULT]="Invalid selection. Default will be used."
MSG_EN[DISK_FSCK_CHECKING]="Checking filesystem for %s..."
MSG_EN[DISK_FSCK_PLEASE_WAIT]="This process may take some time. Please wait..."
MSG_EN[DISK_FSCK_COMPLETED_NO_ERRORS]="Filesystem check completed. No errors found."
MSG_EN[DISK_FSCK_COMPLETED_WITH_CODE]="Filesystem check completed. Error code: %d"
MSG_EN[DISK_FSCK_ERROR_CODE_MEANING]="Error code meaning:"
MSG_EN[DISK_FSCK_CODE_0]="0: No errors"
MSG_EN[DISK_FSCK_CODE_1]="1: Filesystem errors were fixed"
MSG_EN[DISK_FSCK_CODE_2]="2: System restart recommended"
MSG_EN[DISK_FSCK_CODE_4]="4: Filesystem errors were not fixed"
MSG_EN[DISK_FSCK_CODE_8]="8: Operational error"
MSG_EN[DISK_FSCK_CODE_16]="16: Usage error or syntax error"
MSG_EN[DISK_FSCK_CODE_32]="32: Fsck was cancelled"
MSG_EN[DISK_FSCK_CODE_128]="128: Shared library error"

# Health check
MSG_EN[DISK_HEALTH_SCANNING]="Scanning for available drives..."
MSG_EN[DISK_HEALTH_NO_DRIVES]="No drives found. Trying direct search..."
MSG_EN[DISK_HEALTH_NO_DRIVES_FOUND]="No hard drives found or 'smartctl' could not detect any devices."
MSG_EN[DISK_HEALTH_CHECK_ALL_DRIVES]="Would you like to check all detected drives?"
MSG_EN[DISK_HEALTH_STATUS_FOR]="=== Health status for %s ==="
MSG_EN[DISK_HEALTH_FOUND_DRIVES]="Found drives:"
MSG_EN[DISK_HEALTH_SELECT_DRIVE]="Please select a drive (1-%d):"
MSG_EN[DISK_HEALTH_ADDITIONAL_TESTS]="Would you like to perform additional tests?"
MSG_EN[DISK_HEALTH_SHORT_TEST]="Short self-test (takes about 2 minutes)"
MSG_EN[DISK_HEALTH_ATTRIBUTES]="Show extended attributes"
MSG_EN[DISK_HEALTH_BACK]="Back"
MSG_EN[DISK_HEALTH_SELECT_TEST]="Select an option (1-3):"
MSG_EN[DISK_HEALTH_STARTING_SHORT_TEST]="Starting short self-test for %s..."
MSG_EN[DISK_HEALTH_TEST_RUNNING]="The test is now running in the background. After completion you can display the results."
MSG_EN[DISK_HEALTH_TEST_COMPLETION]="The test should be completed in about 2 minutes."
MSG_EN[DISK_HEALTH_WAIT_FOR_RESULTS]="Would you like to wait and display the results?"
MSG_EN[DISK_HEALTH_WAITING]="Waiting 2 minutes for test completion..."
MSG_EN[DISK_HEALTH_TEST_RESULTS]="Test results for %s:"
MSG_EN[DISK_HEALTH_EXTENDED_ATTRIBUTES]="Extended attributes for %s:"
MSG_EN[DISK_HEALTH_OPERATION_CANCELLED]="Operation cancelled."

# Largest files
MSG_EN[DISK_LARGEST_ENTER_PATH]="Enter the path to search in"
MSG_EN[DISK_LARGEST_PATH_NOT_EXIST]="The specified path does not exist or is not a directory."
MSG_EN[DISK_LARGEST_FILE_COUNT]="How many files should be displayed? [Default is 20]:"
MSG_EN[DISK_LARGEST_INVALID_NUMBER]="Invalid input. Please enter a positive number."
MSG_EN[DISK_LARGEST_SEARCHING]="Searching for the %d largest files in %s..."
MSG_EN[DISK_LARGEST_PLEASE_WAIT]="This may take some time for large directories..."
MSG_EN[DISK_LARGEST_SELECT_METHOD]="Which method would you like to use?"
MSG_EN[DISK_LARGEST_METHOD_DU]="du (fast for small directories, also shows directory sizes)"
MSG_EN[DISK_LARGEST_METHOD_FIND]="find (better for large directories, shows only files)"
MSG_EN[DISK_LARGEST_SELECT_METHOD_PROMPT]="Select an option (1-2):"
MSG_EN[DISK_LARGEST_INVALID_USING_DU]="Invalid selection. Using du."

# Error messages
MSG_EN[DISK_ERROR_SMARTCTL_NOT_INSTALLED]="The program 'smartctl' is not installed and could not be installed."
MSG_EN[DISK_ERROR_DU_NOT_INSTALLED]="The program 'du' is not installed and could not be installed."
MSG_EN[DISK_ERROR_LSOF_NOT_INSTALLED]="The program 'lsof' is not installed and could not be installed."
MSG_EN[DISK_ERROR_HDPARM_NOT_INSTALLED]="The program 'hdparm' is not installed and could not be installed."
MSG_EN[DISK_ERROR_FSCK_NOT_INSTALLED]="The program 'fsck' is not installed and could not be installed."

# General messages
MSG_EN[DISK_INVALID_SELECTION]="Invalid selection."
MSG_EN[DISK_BACK_TO_MAIN_MENU]="Back to main menu."
MSG_EN[DISK_INVALID_SELECTION_TRY_AGAIN]="Invalid selection. Please try again."
