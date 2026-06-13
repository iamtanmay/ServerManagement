#!/bin/bash
echo "$1" | sudo -S -s
./ServerManagement/PowerMonUbuntu.sh $1
bash
