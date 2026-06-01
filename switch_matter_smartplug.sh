#!/bin/bash

matter() {
    node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js "$@"
}

if [[ " $1 " == " -1 " ]]; then
    if [[ -f ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js ]]; then
        { echo "nodes status 3"; sleep 20; } | matter | grep "status"
    fi
fi

if [[ " $1 " == " 0 " ]]; then
    if [[ -f ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js ]]; then
        { echo "commands onoff off 3 1"; sleep 20; } | matter
    fi
fi

if [[ " $1 " == " 1 " ]]; then
    if [[ -f ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js ]]; then
        { echo "commands onoff on 3 1"; sleep 20; } | matter
    fi
fi

