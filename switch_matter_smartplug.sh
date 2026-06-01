#!/bin/bash

PIPE="$HOME/matter_pipe"

#matter() {
#    node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js "$@"
#}

if [[ -f ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js ]]; then
	if [ ! -p "$PIPE" ]; then
	    echo "Error: Matter service pipe not found. Is the service running?" >&2
	    exit 1
	fi

	if [[ "$1" == "-1" ]]; then
	    # Note: To read live output, we print to the pipe and then check the console logs
	    echo "nodes status 3" > "$PIPE"
	fi

	if [[ "$1" == "0" ]]; then
	    echo "commands onoff off 3 1" > "$PIPE"
	fi

	if [[ "$1" == "1" ]]; then
	    echo "commands onoff on 3 1" > "$PIPE"
	fi
fi
