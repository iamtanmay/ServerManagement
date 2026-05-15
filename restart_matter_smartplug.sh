#!/bin/bash

alias matter='(node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js)'
{ echo "commands onoff off 3 1"; sleep 15; } | matter
{ echo "commands onoff on 3 1"; sleep 15; } | matter
