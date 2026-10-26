#!/usr/bin/env bash
# 在目标机上跑 NodeQuality（IPQuality + NetQuality 低流量），结果链接打到 stdout
# 交互应答序列 n/y/l/n = 跳过 Hardware / 跑 IP / 低流量 Net / 跳过 Backroute
set -uo pipefail
LOG=/root/nq_last.log
URLFILE=/root/nq_last_url.txt

curl -sL --max-time 60 https://run.NodeQuality.com -o /tmp/nq_run.sh || { echo "NQ_DOWNLOAD_FAIL"; exit 1; }
if [ ! -s /tmp/nq_run.sh ]; then echo "NQ_DOWNLOAD_EMPTY"; exit 1; fi

bash /tmp/nq_run.sh <<< $'n\ny\nl\nn\n' 2>&1 | tee "$LOG" >/dev/null || true
rm -f /tmp/nq_run.sh

URL=$(grep -oP 'https://nodequality\.com/r/[A-Za-z0-9]+' "$LOG" | head -1)
printf '%s\n' "$URL" > "$URLFILE"
echo "URL=$URL"
