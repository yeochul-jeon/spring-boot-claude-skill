#!/bin/bash
# Usage: ./apply-package-structure.sh <projectDir> <style> <basePackagePath>
# style: layered | hexagonal | clean
# 예: ./apply-package-structure.sh ./order-api hexagonal com/example/orderapi
set -euo pipefail

PROJECT="${1:?projectDir 필요}"
STYLE="${2:?style 필요 (layered|hexagonal|clean)}"
PKG="${3:?basePackagePath 필요 (예: com/example/orderapi)}"

SRC="$PROJECT/src/main/java/$PKG"
TEST="$PROJECT/src/test/java/$PKG"
mkdir -p "$SRC" "$TEST"

case "$STYLE" in
  layered)
    mkdir -p "$SRC"/{controller,service,repository,domain,dto,config}
    ;;
  hexagonal)
    mkdir -p "$SRC"/{application/{port/{in,out},service},domain,adapter/{in/web,out/persistence},config}
    ;;
  clean)
    mkdir -p "$SRC"/{domain,application/{usecase,port},infrastructure/{persistence,config},presentation/web}
    ;;
  *)
    echo "ERROR: 알 수 없는 스타일: $STYLE (layered|hexagonal|clean 중 선택)" >&2
    exit 1
    ;;
esac

echo "패키지 구조 적용 완료: $STYLE"
