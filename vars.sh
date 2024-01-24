#!/bin/sh

def_var 'CFG_PL_DISK_MAX_USAGE' 'pl_disk_max_usage' '80' '([1-9]$|^[1-9][0-9]$|^(100))'
def_var 'CFG_PL_DISK_DISCORD_WEBHOOK_URL' 'pl_disk_discord_webhook_url' '' '(|^https://discord.com/api/webhooks/.*)'

