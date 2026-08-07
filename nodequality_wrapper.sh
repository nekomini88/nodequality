#!/usr/bin/env bash
set -euo pipefail

# NodeQuality 自动测速包装脚本（优化版）
# 只跑 IPQuality + NetQuality，跳过耗时的 HardwareQuality 和 Backroute
# 自动发送结果链接到 Telegram

BASE=/root
WORK_DIR="$BASE/nodequality-reports"
mkdir -p "$WORK_DIR"

# 读取配置
CONFIG_FILE="$BASE/nodequality_config.ini"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found"
  exit 1
fi

BOT_TOKEN=$(grep -oP 'bot_token\s*=\s*\K.*' "$CONFIG_FILE" | tr -d '[:space:]')
CHAT_ID=$(grep -oP 'chat_id\s*=\s*\K.*' "$CONFIG_FILE" | tr -d '[:space:]')
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "ERROR: bot_token or chat_id missing in $CONFIG_FILE"
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$WORK_DIR/nodequality_$TIMESTAMP.txt"
LATEST_FILE="$WORK_DIR/latest.txt"
LOG_FILE="$WORK_DIR/nodequality_$TIMESTAMP.log"

echo "========================================"
echo " NodeQuality Auto Test (optimized)"
echo " $TIMESTAMP"
echo "========================================"
echo

# 使用 expect 自动处理交互，全部默认 yes
expect <<'EOF' 2>&1 | tee "$LOG_FILE"
set timeout 2400

spawn bash -c "bash <(curl -sL https://run.NodeQuality.com)"

# 所有提示都发送默认回车（= yes）
expect {
    "运行 HardwareQuality 测试" { send "\n"; exp_continue }
    "运行 IPQuality 测试" { send "\n"; exp_continue }
    "运行 NetQuality 测试" { send "\n"; exp_continue }
    "运行 回程路由追踪" { send "\n"; exp_continue }
    eof
}
EOF

echo
echo "========================================"
echo " Test Complete"
echo "========================================"

# 提取 NodeQuality 结果链接
RESULT_URL=""
if grep -qi "nodequality.com/r/" "$LOG_FILE"; then
  RESULT_URL=$(grep -oP 'https://nodequality\.com/r/[A-Za-z0-9]+' "$LOG_FILE" | head -1)
fi

# 生成精简报告
cat > "$REPORT_FILE" <<EOF
NodeQuality 测速报告
时间: $TIMESTAMP
EOF

if [ -n "$RESULT_URL" ]; then
  cat >> "$REPORT_FILE" <<EOF

结果链接: $RESULT_URL
EOF
fi

cp "$REPORT_FILE" "$LATEST_FILE"

# 发送 Telegram 消息
if [ -n "$RESULT_URL" ]; then
  MSG="🖥️ NodeQuality 每日测速报告
时间: $TIMESTAMP
结果链接: $RESULT_URL"
else
  MSG="🖥️ NodeQuality 每日测速报告
时间: $TIMESTAMP
状态: 执行完成，未找到结果链接"
fi

echo "发送 Telegram 消息..."
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  --data-urlencode "text=$MSG" >/dev/null 2>&1 || echo "Telegram 发送失败"

echo "报告已保存: $REPORT_FILE"
echo "最新报告: $LATEST_FILE"
if [ -n "$RESULT_URL" ]; then
  echo "结果链接: $RESULT_URL"
fi
