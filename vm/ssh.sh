#!/bin/sh
# ssh into the test VM: ./ssh.sh [command]
d="$(dirname "$0")"
exec ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$d/vm_key" -p 2223 user@127.0.0.1 "$@"
