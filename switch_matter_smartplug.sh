#!/bin/bash

matter() {
    node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js "$@"
}

if [[ " $1 " == " 0 " ]]; then
    { echo "commands onoff off 3 1"; sleep 20; } | matter
fi

if [[ " $1 " == " 1 " ]]; then
    { echo "commands onoff on 3 1"; sleep 20; } | matter
fi

