#!/bin/bash
# ADB Shim for WSL
# Redirects adb commands to Windows adb.exe
exec /mnt/d/Softwares/Android/Sdk/platform-tools/adb.exe "$@"
