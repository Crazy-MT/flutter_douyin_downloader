#!/bin/bash
#
# 飞书 Webhook 通知脚本
# 用法: feishu_notify.sh -t <title> -c <content> [-s success|fail]
#

set -euo pipefail

webhook_url="https://open.feishu.cn/open-apis/bot/v2/hook/69c689c7-1d59-4896-b9c6-0d3e43394265"
title=""
content=""
status="success"

print_help() {
  echo "Usage: $0 -t <title> -c <content> [-s success|fail]"
  echo ""
  echo "Options:"
  echo "  -t title    通知标题（必填）"
  echo "  -c content  通知内容（必填）"
  echo "  -s status   构建状态: success 或 fail（默认 success）"
  echo "  -h          显示帮助"
  exit 1
}

while getopts 't:c:s:h' opt; do
  case "$opt" in
    t) title="$OPTARG" ;;
    c) content="$OPTARG" ;;
    s) status="$OPTARG" ;;
    h) print_help ;;
    *) print_help ;;
  esac
done

if [ -z "$title" ] || [ -z "$content" ]; then
  echo "title 和 content 为必填项"
  print_help
fi

# 根据状态选择颜色
if [ "$status" = "success" ]; then
  color="green"
  status_text="✅ 成功"
else
  color="red"
  status_text="❌ 失败"
fi

# 构建者信息
builder="${USER:-unknown}"
build_time="$(date '+%Y-%m-%d %H:%M:%S')"
hostname="$(hostname 2>/dev/null || echo 'unknown')"

# 发送飞书消息（富文本卡片）
payload=$(cat <<EOF
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {
        "tag": "plain_text",
        "content": "${title}"
      },
      "template": "${color}"
    },
    "elements": [
      {
        "tag": "div",
        "fields": [
          {
            "is_short": true,
            "text": {
              "tag": "lark_md",
              "content": "**构建状态：** ${status_text}"
            }
          },
          {
            "is_short": true,
            "text": {
              "tag": "lark_md",
              "content": "**构建者：** ${builder}"
            }
          },
          {
            "is_short": true,
            "text": {
              "tag": "lark_md",
              "content": "**构建时间：** ${build_time}"
            }
          },
          {
            "is_short": true,
            "text": {
              "tag": "lark_md",
              "content": "**主机：** ${hostname}"
            }
          }
        ]
      },
      {
        "tag": "hr"
      },
      {
        "tag": "div",
        "text": {
          "tag": "lark_md",
          "content": "<at id=all></at>\n${content}"
        }
      }
    ]
  }
}
EOF
)

response=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$webhook_url")

http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
  echo "飞书通知发送成功"
else
  echo "飞书通知发送失败 (HTTP $http_code): $body"
fi
