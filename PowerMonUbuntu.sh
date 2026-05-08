#!/bin/bash
# Llama Server Small startup
trap "break" INT
while true; do
	v0=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)

	sleep 1

	v1=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
	cpu_w=$(echo "scale=2; ($v1 - $v0) / 1000000" | bc -l)
	gpu_w=$(nvitop -1 2>/dev/null | grep -oP "\d+W(?= /)" | head -n 1 | grep -oP "\d+" || echo 0)
	total=$(echo "scale=2; $cpu_w + $gpu_w + 7" | bc -l)

	clear

	echo "--- LLM Server Power ---"
	echo "CPU Package: $cpu_w Watts"
	echo "GPU Draw: $gpu_w Watts"
	echo "Rest Pkg: 7 Watts"
	echo "Total Appx: $total Watts"
	echo "Press Ctrl+C to drop to Shell"
done
