#!/bin/bash
# Usage: ./generate-project.sh <artifactId> <dependencies-csv> [outputDir] [javaVersion]
# 예: ./generate-project.sh order-api web,actuator,validation,data-jpa,mysql ./out 21
set -euo pipefail

ARTIFACT="${1:?artifactId가 필요합니다}"
DEPS="${2:?의존성 CSV가 필요합니다 (예: web,actuator)}"
OUT="${3:-./$ARTIFACT}"
JAVA_VER="${4:-21}"

VERSIONS=$("$(dirname "$0")/fetch-latest-versions.sh")
BOOT_VERSION=$(echo "$VERSIONS" | jq -r .bootVersion)

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PKG_NAME="com.example.$(echo "$ARTIFACT" | tr -d '-_')"

curl -sfL "https://start.spring.io/starter.zip" \
  -d "type=gradle-project-kotlin" \
  -d "language=java" \
  -d "bootVersion=$BOOT_VERSION" \
  -d "groupId=com.example" \
  -d "artifactId=$ARTIFACT" \
  -d "name=$ARTIFACT" \
  -d "packageName=$PKG_NAME" \
  -d "packaging=jar" \
  -d "javaVersion=$JAVA_VER" \
  -d "dependencies=$DEPS" \
  -o "$TMP/project.zip"

mkdir -p "$OUT"
unzip -q "$TMP/project.zip" -d "$OUT"

echo "생성 완료: $OUT (Spring Boot $BOOT_VERSION, Java $JAVA_VER)"
echo "base package: $PKG_NAME"
