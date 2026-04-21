#!/bin/bash
# 최신 Spring Boot/Java 버전을 start.spring.io에서 조회해 JSON으로 반환.
# 절대 버전을 하드코딩하지 말 것. 이 스크립트를 사용.
set -euo pipefail

METADATA=$(curl -sfL https://start.spring.io/metadata/client) || {
  echo "ERROR: start.spring.io 접근 실패. 네트워크 확인 필요." >&2
  exit 1
}

BOOT_VERSION=$(echo "$METADATA" | jq -r '.bootVersion.default')
JAVA_DEFAULT=$(echo "$METADATA" | jq -r '.javaVersion.default')
JAVA_VALUES=$(echo "$METADATA" | jq -c '.javaVersion.values | map(.id)')

cat <<EOF
{
  "bootVersion": "$BOOT_VERSION",
  "javaDefault": "$JAVA_DEFAULT",
  "javaAvailable": $JAVA_VALUES
}
EOF
