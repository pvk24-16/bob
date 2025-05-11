#!/bin/sh
echo -ne '\033c\033]0;Visualization test\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Fountain.x86_64" "$@"
