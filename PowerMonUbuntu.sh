#!/bin/bash
# Llama Server Small startup
trap "break" INT
while true; do
	sleep 2
	clear
	echo "--- LLM Server Power ---"
	pwr_round=0
	total_power=0

	#Rest Package estimate
	rest_pwr=10

	#INTEL
	intel_pwr=0
	if [ -d /sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:0 ]; then
		e1=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:0/energy_uj)
		sleep 0.2
		e2=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:0/energy_uj)
		intel_pwr=$(echo "scale=2; ($e2 - $e1) / 200000" | bc)
		pwr_round=$(echo "$intel_pwr" | awk '{print int($1+0.5)}')
		total_power=$((total_power + pwr_round))

		echo "-> GPU [Intel iGPU-RAPL]: ${intel_pwr} W"
	fi

	#NVIDIA
	nvidia_pwr=0
	if command -v nvidia-smi &> /dev/null; then
		nv_data=$(nvidia-smi --query-gpu=index,name,power.draw --format=csv,noheader,nounits 2>/dev/null)

		if [ ! -z "$nv_data" ]; then
			while read -r line; do
				idx=$(echo "$line" | cut -d',' -f1 | xargs)
				name=$(echo "$line" | cut -d',' -f2 | xargs)
				nvidia_pwr=$(echo "$line" | cut -d',' -f3 | xargs)

				pwr_round=$(echo "$nvidia_pwr" | awk '{print int($1+0.5)}')
				total_power=$((total_power + pwr_round))

				echo "-> GPU [NV:$idx] $name: ${nvidia_pwr} W"
			done <<< "$nv_data"
		fi
	fi

	#AMD
	amd_pwr=0
	if command -v rocm-smi &> /dev/null; then
		amd_data=$(rocm-smi --showpower --csv 2>/dev/null | grep -v "device" | grep -v "Device")

		if [ ! -z "$amd_data" ]; then
			while read -r line; do
				idx=$(echo "$line" | cut -d',' -f1 | xargs)
				amd_pwr=$(echo "$line" | cut -d',' -f2 | xargs)

				pwr_round=$(echo "$amd_pwr" | awk '{print int($1+0.5)}')
				total_power=$((total_power + pwr_round))

				echo "-> GPU [AMD:$idx]: ${amd_pwr} W"
			done <<< "$amd_data"
		fi
	fi

	echo "-> Rest Pkg: ${rest_pwr} W"
	total_power=$((total_power + rest_pwr))
	echo "-> Total Power: ${total_power} W"

	echo "Press Ctrl+C to drop to Shell"
done
