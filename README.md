# NodeQuality 每日测速定时推送

通过 [NodeQuality](https://nodequality.com) 基准测试对 VPS 进行每日自动测速，并将结果链接推送到 Telegram 频道。

## 方案总览

```
┌─────────────┐   每天 03:05 (Hermes cron)
│  Hermes cron │──────────────┐
└─────────────┘              ▼
                     ┌─────────────────┐
                     │ nodequality_    │
                     │ wrapper.sh      │
                     └────────┬────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ expect 自动应答   │
                    │ 运行 NodeQuality  │
                    │ (IP+Net 测试)     │
                    └────────┬─────────┘
                             │ 解析结果链接
                             ▼
                    ┌──────────────────┐
                    │ Telegram 推送     │
                    │ 报告到频道        │
                    └──────────────────┘
```

- **调度**：Hermes cron job `e886f0387fe3`，每天 `03:05`（北京时间）执行
- **执行**：`expect` 自动应答 NodeQuality 交互式提示（默认全部 yes），跳过耗时的 HardwareQuality 与回程路由测试
- **报告**：提取结果链接 `https://nodequality.com/r/<id>`，生成精简报告并推送 Telegram
- **留存**：每次测试完整日志 + 精简报告保存在 `nodequality-reports/`，`latest.txt` 指向最新结果

## 文件结构

```
├── nodequality_wrapper.sh            # 主脚本：expect 自动化 + 报告生成 + TG 推送
├── nodequality_config.example.ini    # 配置示例（复制为 nodequality_config.ini 后填写）
├── nodequality_config.ini            # 实际配置（.gitignore 排除，不提交）
└── nodequality-reports/              # 运行产物（日志 + 精简报告）
    └── latest.txt                    # 最新一次报告
```

## 快速开始

### 1. 配置

编辑 `nodequality_config.example.ini` 并复制为 `nodequality_config.ini`：

```ini
[telegram]
bot_token = <你的 Bot Token>
chat_id = <频道 ID，如 -1001234567890>
```

### 2. 手动运行

```bash
bash nodequality_wrapper.sh
```

脚本会：
1. 用 `expect` 运行 `bash <(curl -sL https://run.NodeQuality.com)`，自动应答全部提示
2. 捕获完整日志到 `nodequality-reports/nodequality_<时间戳>.log`
3. 从日志提取结果链接，生成精简报告
4. 通过 Telegram Bot API 推送报告到配置的频道

### 3. 定时调度（Hermes cron）

创建 cron job：

```bash
hermes cron create \
  --name "NodeQuality 每日测速" \
  --schedule "5 3 * * *" \
  --prompt "Run the NodeQuality auto test wrapper script located at /root/nodequality_wrapper.sh. Execute: cd /root && bash nodequality_wrapper.sh. The script reads /root/nodequality_config.ini for bot_token and chat_id, runs the NodeQuality benchmark with default options, captures the result URL, and sends a Telegram message with the link. After execution, report the outcome to the user."
```

> 也可以直接用 `cronjob` 工具创建（等价配置）。

## 推送效果

推送消息示例：

```
🖥️ NodeQuality 每日测速报告
时间: 2026-08-07_03-09-00
结果链接: https://nodequality.com/r/BQqxHrjS8VABKk2W6E1jv1NLmld3R0Aq
```

## 依赖

- `expect`（自动应答交互式脚本）
- `curl`（下载 NodeQuality 脚本、推送 Telegram）
- `bash`（>= 4）

```bash
# Debian/Ubuntu
apt install -y expect curl
```

## 注意事项

- 脚本运行时长约 5-15 分钟（IPQuality + NetQuality），`expect` 超时设为 2400s
- 若测试失败未产生结果链接，会推送"执行完成，未找到结果链接"的提示消息
- 完整日志保留在 `nodequality-reports/` 便于排查
