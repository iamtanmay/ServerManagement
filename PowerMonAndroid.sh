#!/bin/bash

echo "Get latest ServerManagement changes for Android Gateway..."
PULL_OUTPUT=$(git -C $HOME/ServerManagement pull 2>&1)
echo "$PULL_OUTPUT"
FIRST_LINE=$(echo "$PULL_OUTPUT" | head -n 1)

if [[ ! "$FIRST_LINE" =~ "Already up to date" ]]; then
    echo "New changes detected. Restarting script..."
    exec "$0" "$@"
fi

convert_time_format() {
    awk '{
        gsub(/[^0-9]/,"",$4); 
        gsub(/[^0-9]/,"",$5); 
        s=$5; 
        d=int(s/86400); s%=86400; 
        h=int(s/3600); s%=3600; 
        m=int(s/60); s%=60; 
        print "" $4 "          UP          " d "days" h "h" m "m" s "s"
    }'
}

trap "break" INT

while true; do
	battery_json=$(termux-battery-status)

	# 1. Battery Data
	voltage_mv=$(echo "$battery_json" | grep "voltage" | grep -oE "\-?[0-9]+" | head -n 1)
	current_ua=$(echo "$battery_json" | grep "current" | grep -oE "\-?[0-9]+" | head -n 1)
	current_avg=$(echo "$battery_json" | grep "current_average" | grep -oE "\-?[0-9]+" | head -n 1)
	percentage=$(echo "$battery_json" | grep "percentage" | grep -oE "[0-9]+")

	# 2. CPU Usage (Termux-Internal Workaround)
	# Sums up the %CPU column for all processes Termux can see
	cpu_usage=$(ps -eo %cpu | awk '{s+=$1} END {printf "%.1f", s/8}')

	# 3. RAM Usage (From /proc/meminfo)
	mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
	mem_used=$(( (mem_total - mem_avail) / 1024 ))
	mem_perc=$(echo "scale=1; 100 * ($mem_total - mem_avail) / $mem_total" | bc -l)


	# 3. RAM Usage (From /proc/meminfo)
	mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
	mem_used=$(( (mem_total - mem_avail) / 1024 ))
	mem_perc=$(echo "scale=1; 100 * ($mem_total - mem_avail) / $mem_total" | bc -l)

	# 4. Power Logic
	if [[ -z "$current_ua" || "$current_ua" -eq 0 ]]; then
	use_current=${current_avg#-}
	else
	use_current=${current_ua#-}
	fi

	if [[ -n "$voltage_mv" && -n "$use_current" && "$use_current" -ne 0 ]]; then
	total_w=$(echo "scale=4; ($voltage_mv / 1000) * ($use_current / 1000000)" | bc -l)
	else
	total_w="0.0000"
	fi

	avg_w=$(echo "scale=4; ($voltage_mv / 1000) * ${current_avg:-0} / -1000" | bc -l)

	clear
	echo "------------Android Gateway------------"
	printf "CPU Usage:       %s%%\n" "$cpu_usage"
	printf "RAM Usage:       %d MB (%s)\n" "$mem_used" "$(echo "scale=2; $mem_total / 1024" | bc -l)"
	echo "Battery Level:   $percentage %"
	printf "Voltage:         %.2f V\n" "$(echo "scale=2; $voltage_mv / 1000" | bc -l)"
	printf "Current Draw:    %.2f mA\n" "$(echo "scale=2; ${current_ua:-0} / -1000" | bc -l)"
	printf "Avg Current :    %.2f mA\n" "$(echo "scale=2; ${current_avg:-0} / -1000" | bc -l)"
	printf "Avg Power:       %.4f W\n" "$avg_w"
	printf "Current Power:   %.4f W\n" "$total_w"
	echo "------------Services------------------"
	echo "Service          PID          Status          UPTIME"
	printf "Matter:          "
	sv -w 1 status matter-shell | convert_time_format

	printf "Homepage:        "
	sv -w 1 status homepage | convert_time_format

	#    printf "Gitea:"
	#sv -w 1 status gitea | convert_time_format

	#    printf "NGINX:"
	#sv -w 1 status gitea | convert_time_format

	#    printf "Prometheus:"
	#sv -w 1 status gitea | convert_time_format

	#    printf "\nHomepage Logs:"
	#    tail -n 10 ~/homepage/logs/current
	echo "----------------------------"
	echo "Press Ctrl+C to drop to Shell"

	sleep 1
done
bash
