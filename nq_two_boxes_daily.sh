#!/usr/bin/env bash
# 两台大盘鸡 NodeQuality 每日测速 → 频道 nekomini_服务器nq
# 由 cron(no_agent) 调用：stdout 即推送内容；无输出=不推送。
# 03:00(UTC+8) 触发。两机**并行**跑（各约 5-7 分钟），输出按固定顺序打印。
set -uo pipefail

K="-i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes -o ServerAliveInterval=30"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 标签|IP
HOSTS=(
  "新存储-4T|109.107.140.95"
  "老存储-492G|193.111.31.176"
)

# 1) 并行起跑
i=0
for entry in "${HOSTS[@]}"; do
  ip="${entry##*|}"
  ( timeout 2400 ssh $K root@"$ip" 'bash /root/nq_run.sh' > "$TMP/$i.out" 2>&1 ) &
  i=$((i + 1))
done
wait

# 2) 按固定顺序汇报
printf '🖥️ NodeQuality 每日测速 · 两台大盘鸡\n⏰ %s (UTC+8)\n' "$(date '+%Y-%m-%d %H:%M')"
i=0
for entry in "${HOSTS[@]}"; do
  tag="${entry%%|*}"
  ip="${entry##*|}"
  out="$TMP/$i.out"
  url=$(grep -oP 'https://nodequality\.com/r/[A-Za-z0-9]+' "$out" 2>/dev/null | head -1)
  if [ -n "$url" ]; then
    printf '\n🏷️ %s\n🌐 IP: %s\n🔗 结果: %s\n' "$tag" "$ip" "$url"
  else
    tail_txt=$(tail -3 "$out" 2>/dev/null | tr '\n' ' ' | cut -c1-200)
    [ -z "$tail_txt" ] && tail_txt="(无输出)"
    printf '\n⚠️ %s\n🌐 IP: %s\n📋 未取到结果链接，输出尾部: %s\n' "$tag" "$ip" "$tail_txt"
  fi
  i=$((i + 1))
done
