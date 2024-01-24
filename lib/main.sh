#!/bin/bash

if [ ! -x "$(command -v df)" ]
then
	echo "Error: please install df"
	exit 1
fi
if [ ! -x "$(command -v du)" ]
then
	echo "Error: please install du"
	exit 1
fi
if [ ! -x "$(command -v awk)" ]
then
	echo "Error: please install awk"
	exit 1
fi

# current dir is root of server/

_alerts=()

build_alert_msg() {
	[[ "${#_alerts[@]}" == "0" ]] && return

	local server_folder_du
	server_folder_du="$(du -hd 1)"
	local alert_msg=''
	alert_msg+="!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
	alert_msg+="!!! Disk pressure alert on $CFG_SRV_NAME !!!\n"
	alert_msg+="!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
	alert_msg+="date: $(date)\n"
	alert_msg+="max disk usage: ${CFG_PL_DISK_MAX_USAGE}%\n"
	alert_msg+="Folder storage usage in $CFG_SRV_NAME:\n"
	alert_msg+="${server_folder_du}\n"
	alert_msg+="disks:\n"
	local alert
	for alert in "${_alerts[@]}"
	do
		alert_msg+="$alert\n"
	done
	echo "$alert_msg"
}

escape_json_str() {
	local text="$1"
	if [ -x "$(command -v jq)" ]
	then
		echo -n "$text" | jq -Rrsa .
	else
		printf '"'
		printf "%s" "$text" | sed 's/\\/\\\\/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g'
		printf '"'
	fi
}

_send_discord() {
	local message="$1"
	local url
	url="${CFG_PL_DISK_DISCORD_WEBHOOK_URL:-}"
	[[ "$url" == "" ]] && return

	local tmp_json=./lib/tmp/plugin_disk_discord_payload.json
	message="$(escape_json_str "$message")"
	printf '{"content": %s}' "$message" > "$tmp_json"
	curl \
		-H "Accept: application/json" \
		-H "Content-Type:application/json" \
		-X POST \
		--data @"$tmp_json" \
		"$url"
	rm "$tmp_json"
}

_send_logfile() {
	local message="$1"
	printf '%b\n' "$message"
}

send_alerts() {
	local alert_msg
	alert_msg="$(build_alert_msg)"
	[[ "$alert_msg" == "" ]] && return

	_send_logfile "$alert_msg"
	_send_discord "$alert_msg"
}

add_alert() {
	local msg="$1"
	_alerts+=("$msg")
}

check_disk_usage() {
	local disk
	local usage
	while read -r disk
	do
		usage="$(echo "$disk" | awk '{ print $5 }')"
		echo "usage: $usage"
		if [[ "$usage" == *% ]]
		then
			usage="${usage::-1}"
		fi
		if [ "$usage" == "" ]
		then
			echo "Warning: failed to get usage for the following disk"
			echo "  $disk"
			continue
		fi
		if [ "$usage" -gt "$CFG_PL_DISK_MAX_USAGE" ]
		then
			add_alert "Warning: disk pressure $disk"
		fi
	done < <(df -h | grep -Ev '^(/dev/loop|tmpfs|udev|Filesystem)' | grep -Ev '(/boot/efi)$')
	df -h | grep -Ev '^(/dev/loop|tmpfs|udev|Filesystem)' | grep -Ev '(/boot/efi)$'
}

check_disk_usage
send_alerts

