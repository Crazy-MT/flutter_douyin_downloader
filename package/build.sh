#!/bin/bash
#open /Applications/FlClash.app
set -o pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$script_dir/.."

#fvm use 3.24.5
flutter_bin="${FLUTTER_BIN:-/Users/mt/fvm/versions/3.24.5/bin/flutter}"
build_timestamp="$(date '+%Y%m%d_%H%M%S')"
log_dir="$script_dir/build/logs"
mkdir -p "$log_dir"
git_ref_description=""

summarize_failure_reason() {
  local log_file="$1"
  local fallback="$2"

  if [ ! -s "$log_file" ]; then
    printf '%s' "$fallback"
    return
  fi

  local summary
  summary=$(
    grep -Ei 'error:|错误|失败|failed|failure|exception|no profiles|provision|signing|certificate|could not|operation not permitted' "$log_file" |
      tail -n 8
  )

  if [ -z "$summary" ]; then
    summary=$(tail -n 12 "$log_file")
  fi

  printf '%s\n' "$summary" |
    sed "s/[\"\\\\\`]/'/g" |
    awk '
      {
        sub(/^[[:space:]]+/, "");
        sub(/[[:space:]]+$/, "");
        if (length($0) > 0) {
          if (count > 0) {
            printf "\\n";
          }
          printf "%s", $0;
          count++;
        }
      }
    '
}

net_constant_file="./lib/network/net_constant.dart"
host_line=$(
  grep -E \
    '^[[:space:]]*static[[:space:]]+String[[:space:]]+HOST[[:space:]]*=' \
    "$net_constant_file" |
    head -n 1
)

if [ -z "$host_line" ]; then
  echo "❌ 未找到 NetConstant.HOST，无法判断蒲公英详情描述"
  exit 1
fi

if echo "$host_line" | grep -qi 'test'; then
  pgyer_build_description="测试环境"
else
  pgyer_build_description="正式环境"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  git_hash="$(git rev-parse --short HEAD 2>/dev/null || true)"
  if [ -n "$git_branch" ] && [ -n "$git_hash" ]; then
    git_ref_description=" [${git_branch}@${git_hash}]"
  fi
fi

pgyer_extra_description="$*"
if [ -n "$pgyer_extra_description" ]; then
  pgyer_build_description="${pgyer_build_description} ${pgyer_extra_description}"
fi
pgyer_build_description="${pgyer_build_description}${git_ref_description}"
pgyer_url="https://www.pgyer.com/zhuboyi-260719"
ios_export_args=(--export-options-plist=./package/ExportOptions.plist)
ios_export_note=""
if ! security find-identity -v -p codesigning 2>/dev/null | grep -Eq '"(Apple Distribution|iOS Distribution):'; then
  ios_export_args=(--export-method development)
  ios_export_note="，development 签名"
  echo "未找到 Apple Distribution/iOS Distribution 证书，iOS 改用 development 导出"
fi

echo "蒲公英详情描述: ${pgyer_build_description}"

# 清理旧产物
rm -rf ./build/app/outputs/flutter-apk/app-release.apk
rm -rf ./build/app/outputs/flutter-apk/app-debug.apk
rm -rf ./build/ios/ipa/code_zero.ipa
rm -f /tmp/build_apk_result /tmp/build_ios_result /tmp/build_apk_reason /tmp/build_ios_reason

# ===== 串行执行 =====

# 先把 minSdk 改成 23
if [ -f "./android/app/build.gradle.kts" ]; then
  perl -pi -e 's/^(\s*)minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)$/${1}minSdk = 23/' ./android/app/build.gradle.kts
fi

# build apk
(
  apk_log="$log_dir/apk_${build_timestamp}.log"
  "$flutter_bin" build apk --release --obfuscate --split-debug-info=./symbols 2>&1 | tee "$apk_log"
  apk_result=$?
  if [ $apk_result -eq 0 ] && [ -f ./build/app/outputs/flutter-apk/app-release.apk ]; then
    echo "开始上传 APK 到蒲公英，日志：$apk_log"
    ./package/pgyer_upload.sh \
      -k 98e445172e8942aece1d0eac22f0270e \
      -d "${pgyer_build_description}" \
      ./build/app/outputs/flutter-apk/app-release.apk >> "$apk_log" 2>&1
    upload_result=$?
    if [ $upload_result -eq 0 ]; then
      echo "success" > /tmp/build_apk_result
    else
      echo "fail" > /tmp/build_apk_result
      {
        printf '蒲公英上传失败：'
        summarize_failure_reason "$apk_log" "上传命令退出码 ${upload_result}"
        printf '\\n日志：%s' "$apk_log"
      } > /tmp/build_apk_reason
    fi
  else
    echo "fail" > /tmp/build_apk_result
    {
      summarize_failure_reason "$apk_log" "Flutter APK 构建失败，退出码 ${apk_result}"
      printf '\\n日志：%s' "$apk_log"
    } > /tmp/build_apk_reason
  fi
  afplay /System/Library/Sounds/Glass.aiff
)

# build ios
(
  ios_log="$log_dir/ios_${build_timestamp}.log"
  "$flutter_bin" build ipa --release --export-options-plist=./package/ExportOptions.plist 2>&1 | tee "$ios_log"
  ios_build_result=$?
  if [ $ios_build_result -eq 0 ] && [ -f ./build/ios/ipa/code_zero.ipa ]; then
    echo "开始上传 iOS IPA 到蒲公英，日志：$ios_log"
    ./package/pgyer_upload.sh \
      -k 98e445172e8942aece1d0eac22f0270e \
      -d "${pgyer_build_description}" \
      ./build/ios/ipa/code_zero.ipa >> "$ios_log" 2>&1
    upload_result=$?
    if [ $upload_result -eq 0 ]; then
      echo "success" > /tmp/build_ios_result
    else
      echo "fail" > /tmp/build_ios_result
      {
        printf '蒲公英上传失败：'
        summarize_failure_reason "$ios_log" "上传命令退出码 ${upload_result}"
        printf '\\n日志：%s' "$ios_log"
      } > /tmp/build_ios_reason
    fi
  else
    echo "fail" > /tmp/build_ios_result
    {
      if [ $ios_build_result -eq 0 ]; then
        printf 'Flutter IPA 构建命令返回成功，但未生成 build/ios/ipa/code_zero.ipa'
      else
        summarize_failure_reason "$ios_log" "Flutter IPA 构建失败，退出码 ${ios_build_result}"
      fi
      if [ -s ./build/ios/ipa/Packaging.log ]; then
        printf '\\nPackaging.log 最后记录：'
        tail -n 8 ./build/ios/ipa/Packaging.log |
          sed "s/[\"\\\\\`]/'/g" |
          awk '
            {
              sub(/^[[:space:]]+/, "");
              sub(/[[:space:]]+$/, "");
              if (length($0) > 0) {
                if (count > 0) {
                  printf "\\n";
                }
                printf "%s", $0;
                count++;
              }
            }
          '
      fi
      printf '\\n日志：%s' "$ios_log"
    } > /tmp/build_ios_reason
  fi
)

apk_status=$(cat /tmp/build_apk_result 2>/dev/null || echo "fail")
ios_status=$(cat /tmp/build_ios_result 2>/dev/null || echo "fail")
apk_reason=$(cat /tmp/build_apk_reason 2>/dev/null || true)
ios_reason=$(cat /tmp/build_ios_reason 2>/dev/null || true)
rm -f /tmp/build_apk_result /tmp/build_ios_result /tmp/build_apk_reason /tmp/build_ios_reason

# 发送飞书通知
notify_status="success"
notify_content=""

if [ "$apk_status" = "success" ]; then
  notify_content="${notify_content}**APK 构建：** ✅ 成功（${pgyer_build_description}），已上传蒲公英：${pgyer_url}\n"
else
  notify_status="fail"
  notify_content="${notify_content}**APK 构建：** ❌ 失败"
  if [ -n "$apk_reason" ]; then
    notify_content="${notify_content}\n失败原因：${apk_reason}"
  fi
  notify_content="${notify_content}\n"
fi

if [ "$ios_status" = "success" ]; then
  notify_content="${notify_content}**iOS 构建：** ✅ 成功（${pgyer_build_description}${ios_export_note}），已上传蒲公英：${pgyer_url}"
else
  notify_status="fail"
  notify_content="${notify_content}**iOS 构建：** ❌ 失败"
  if [ -n "$ios_reason" ]; then
    notify_content="${notify_content}\n失败原因：${ios_reason}"
  fi
fi

"$script_dir/feishu_notify.sh" \
  -t "📦 打包通知（build.sh）" \
  -c "$notify_content" \
  -s "$notify_status"

automator ./package/buildios.workflow
