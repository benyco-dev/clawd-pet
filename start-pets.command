#!/bin/bash
# Start all desktop pets (restarts them if already running).
launchctl kickstart -k "gui/$(id -u)/com.clawd.pet"
