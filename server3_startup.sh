#!/bin/bash
echo "$1" | sudo -S -s
sudo chmod -R a+r /sys/class/powercap/intel-rapl
./ServerManagement/PowerMonUbuntu.sh $1
bash
