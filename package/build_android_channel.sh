#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
request_file="$project_dir/lib/network/l_request.dart"
apk_file="$project_dir/build/app/outputs/flutter-apk/app-release.apk"
api_key="${PGYER_API_KEY:-98e445172e8942aece1d0eac22f0270e}"
keep_channel=0
channels=(official vivo oppo xiaomi honor huawei tencent)
git_ref_description=""

# 先把 minSdk 改成 23
if [ -f "./android/app/build.gradle.kts" ]; then
  perl -pi -e 's/^(\s*)minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)$/${1}minSdk = 23/' ./android/app/build.gradle.kts
fi

print_help() {
  echo "Usage: $0 [--keep-channel] [channel ...]"
  echo ""
  echo "Build Android release APKs and upload them to PGYER."
  echo ""
  echo "Options:"
  echo "  --keep-channel  Keep the last channel in lib/network/l_request.dart"
  echo "  -h, --help      Show this help"
  echo ""
  echo "Default channels: ${channels[*]}"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 vivo huawei"
  echo "  PGYER_API_KEY=xxx $0 --keep-channel official vivo"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep-channel)
      keep_channel=1
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  channels=("$@")
fi

if [ ! -f "$request_file" ]; then
  echo "Missing request file: $request_file"
  exit 1
fi

if git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch="$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  git_hash="$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null || true)"
  if [ -n "$git_branch" ] && [ -n "$git_hash" ]; then
    git_ref_description=" [${git_branch}@${git_hash}]"
  fi
fi

for channel in "${channels[@]}"; do
  if ! echo "$channel" | grep -Eq '^[A-Za-z0-9_-]+$'; then
    echo "Channel can only contain letters, numbers, underscores, and hyphens."
    echo "Invalid channel: $channel"
    exit 1
  fi
done

original_channel="$(
  sed -nE \
    's/^[[:space:]]*dio\.options\.headers\["channel"\][[:space:]]*=[[:space:]]*"([^"]*)";[[:space:]]*$/\1/p' \
    "$request_file" |
    head -n 1
)"

if [ -z "$original_channel" ]; then
  echo 'Could not find dio.options.headers["channel"] in l_request.dart.'
  exit 1
fi

restore_original_channel() {
  if [ "$keep_channel" -eq 0 ]; then
    set_channel "$original_channel"
  fi
}

set_channel() {
  next_channel="$1"
  CHANNEL_TO_SET="$next_channel" perl -0pi -e \
    's/^([ \t]*)dio\.options\.headers\["channel"\]\s*=\s*"[^"]*";/${1}dio.options.headers["channel"] = "$ENV{CHANNEL_TO_SET}";/m' \
    "$request_file"

  active_channel="$(
    sed -nE \
      's/^[[:space:]]*dio\.options\.headers\["channel"\][[:space:]]*=[[:space:]]*"([^"]*)";[[:space:]]*$/\1/p' \
      "$request_file" |
      head -n 1
  )"

  if [ "$active_channel" != "$next_channel" ]; then
    echo "Failed to set Android channel to: $next_channel"
    exit 1
  fi
}

trap restore_original_channel EXIT

cd "$project_dir"

echo "Android channels: ${channels[*]}"

success_channels=()
failed_channels=()

for channel in "${channels[@]}"; do
  echo "--------------------------------"
  echo "Android channel: $channel"
  pgyer_description="${channel}${git_ref_description}"
  echo "PGYER description: $pgyer_description"

  set_channel "$channel"

  rm -f "$apk_file"

  if fvm flutter build apk --release --obfuscate --split-debug-info=./symbols; then
    if [ ! -f "$apk_file" ]; then
      echo "APK was not generated: $apk_file"
      failed_channels+=("$channel")
      continue
    fi

    if "$script_dir/pgyer_upload.sh" \
      -k "$api_key" \
      -d "$pgyer_description" \
      "$apk_file"; then
      success_channels+=("$channel")
    else
      failed_channels+=("$channel")
    fi
  else
    failed_channels+=("$channel")
  fi
done

# 发送飞书通知
notify_status="success"
notify_content=""
pgyer_url="https://www.pgyer.com/zhuboyi-260719"

if [ ${#success_channels[@]} -gt 0 ]; then
  notify_content="${notify_content}**成功渠道：** ${success_channels[*]}\n 已上传蒲公英：${pgyer_url}"
fi

if [ ${#failed_channels[@]} -gt 0 ]; then
  notify_status="fail"
  notify_content="${notify_content}**失败渠道：** ${failed_channels[*]}\n"
fi

if [ ${#success_channels[@]} -eq 0 ] && [ ${#failed_channels[@]} -eq 0 ]; then
  notify_status="fail"
  notify_content="没有完成任何渠道的构建"
fi

"$script_dir/feishu_notify.sh" \
  -t "📦 渠道包打包通知" \
  -c "$notify_content" \
  -s "$notify_status"

if [ ${#failed_channels[@]} -gt 0 ]; then
  echo "Failed channels: ${failed_channels[*]}"
  exit 1
fi

echo "Done: ${channels[*]}"
