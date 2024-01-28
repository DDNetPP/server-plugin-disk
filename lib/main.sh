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

repeat_str() {
	local text="$1"
	local num="$2"
	local i
	for((i=0;i<num;i++))
	do
		printf '%s' "$text"
	done
}

build_alert_msg() {
	[[ "${#_alerts[@]}" == "0" ]] && return

	local server_folder_du
	server_folder_du="$(du -hd 1 | awk '{ print "  " $0 }')"
	local alert_msg=''
	local header_len=45
	alert_msg+="$(repeat_str '!' "$header_len")\n"
	alert_msg+="!!! $(printf '%-*s' "$((header_len - 8))" "Disk pressure alert on $CFG_SRV_NAME") !!!\n"
	alert_msg+="$(repeat_str '!' "$header_len")\n"
	alert_msg+="date: $(date)\n"
	alert_msg+="$(repeat_str '-' "$header_len")\n"
	alert_msg+="Folder storage usage in $CFG_SRV_NAME:\n"
	alert_msg+="${server_folder_du}\n"
	alert_msg+="$(repeat_str '-' "$header_len")\n"
	local alert
	for alert in "${_alerts[@]}"
	do
		alert_msg+="$alert\n"
	done
	echo -e "$alert_msg"
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
	_send_discord '```'"$alert_msg"'```'
}

add_alert() {
	local msg="$1"
	_alerts+=("$msg")
}

check_disk_usage() {
	local disk
	local usage
	local warning_disks=()
	local used
	local size
	while read -r disk
	do
		usage="$(echo "$disk" | awk '{ print $5 }')"
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
			warning_disks+=("$disk")
			used="$(echo "$disk" | awk '{ print $3 }')"
			size="$(echo "$disk" | awk '{ print $2 }')"
		fi
	done < <(df -h | grep -Ev '^(/dev/loop|tmpfs|udev|Filesystem)' | grep -Ev '(/boot/efi)$')
	if [ "${#warning_disks[@]}" -gt "0" ]
	then
		add_alert "YOUR DISK USAGE: ${usage}% $size/$used"
		add_alert "MAX  DISK USAGE: ${CFG_PL_DISK_MAX_USAGE}%"
	elif [ "${#warning_disks[@]}" -gt "0" ]
	then
		add_alert "Disks with more than ${CFG_PL_DISK_MAX_USAGE}% usage:"
		add_alert "  $(df -h | head -n1)"
	fi
	for disk in "${warning_disks[@]}"
	do
		add_alert "  $disk"
	done
}

check_disk_usage
send_alerts

