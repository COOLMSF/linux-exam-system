#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <linux-username>"
  exit 1
fi

USERNAME="$1"
SERVICE_SRC="$(dirname "$0")/exam-agent.service"
SERVICE_DST="/etc/systemd/system/exam-agent@.service"

sudo cp "$SERVICE_SRC" "$SERVICE_DST"
sudo systemctl daemon-reload
sudo systemctl enable "exam-agent@${USERNAME}.service"
sudo systemctl restart "exam-agent@${USERNAME}.service"

echo "Service installed: exam-agent@${USERNAME}.service"
echo "Status:"
sudo systemctl status "exam-agent@${USERNAME}.service" --no-pager
