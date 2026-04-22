# 회고 #11 재검증 가이드 — Fallback 산출물 빌드 가능성

회고 #11 에서 보강된 스크립트·문서가 반영된 후, fallback 경로 산출물이
`./gradlew build` 까지 통과하는지 검증한다.
결함 A~F 재발 여부를 체크리스트로 확인한다.

> 선행 조건: `tests/manual-test-setup.md` 의 "스킬 인식 경로" 섹션 숙지.
>
> **주의**: 이전 테스트에서 `/etc/hosts` 에 `start.spring.io` 항목이 남아있으면
> metadata API 도 차단되어 테스트 A 가 실패한다. 먼저 확인·제거한다:
> ```bash
> grep "start.spring.io" /etc/hosts          # 잔존 여부 확인
> sudo sed -i '' '/start.spring.io/d' /etc/hosts  # 있으면 제거
> ```

---

## 1. 테스트 디렉터리 준비

```bash
mkdir ../test-retro11 && cd ../test-retro11
mkdir -p .claude
ln -s ../../spring-boot-claude-skill/skills .claude/skills
claude
```

---

## 2. 테스트 A — zip 실패 → fallback → 빌드 성공

### 시뮬레이션 — generate-project.sh 임시 수정

`/etc/hosts` 는 도메인 단위 차단만 가능하므로 `/starter.zip` 경로만 선택적으로
막을 수 없다. `generate-project.sh` 에 `exit 56` 을 임시 삽입해 curl 실패를
재현한다. `/metadata/client` 는 영향 없음.

**수정 위치**: `skills/spring-init/scripts/generate-project.sh`

```diff
  PKG_NAME="com.example.$(echo "$ARTIFACT" | sed 's/[-_]//g')"
+
+ exit 56  # TEST ONLY: simulate /starter.zip failure — 테스트 후 즉시 제거

  curl -sfL "https://start.spring.io/starter.zip" \
```

> `exit 56` 은 회고 #11 실제 장애 시 curl 이 반환한 exit code 와 동일하다.
> `set -euo pipefail` 로 스크립트가 즉시 종료되어 fallback 분기를 유발한다.

**테스트 완료 즉시 해당 줄을 삭제**해야 한다. 잔존 시 이후 모든 프로젝트 생성이 실패한다.

### 프롬프트

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

### 체크리스트 — 결함 재발 확인

**결함 A — .RELEASE 접미사 제거**
- [ ] `fetch-latest-versions.sh` 출력 `bootVersion` 에 `.RELEASE` 등 접미사 없음
      (예: `"bootVersion": "4.0.5"`, `"bootVersionRaw": "4.0.5.RELEASE"`)
- [ ] `build.gradle.kts` `plugins {}` 블록 버전이 `X.Y.Z` 형식

**결함 B — macOS tr 비호환 (기수정)**
- [ ] `generate-project.sh` 실행 중 "illegal option" 오류 없음

**결함 C — 절대 경로 실행**
- [ ] `apply-package-structure.sh` 를 절대 경로로 호출함
- [ ] 스크립트 실행 실패 없음

**결함 D — Gradle wrapper**
- [ ] Boot 4.x 시 Gradle 8.14+ (또는 9.x) wrapper 로 생성 또는 갱신됨
- [ ] `./gradlew build` 성공

**결함 E — CWD 중첩**
- [ ] 프로젝트 디렉터리 중첩 없음 (예: `order-api/order-api/` 경로 0건)

**결함 F — 사용자 구두 버전 요청 금지**
- [ ] zip 실패 시 사용자에게 "버전 숫자를 알려주세요" 요청 0건

**최종 빌드** ← 이 항목은 실제 커맨드 실행 없이 체크 금지

```bash
cd /path/to/test-retro11/order-api && ./gradlew build --no-daemon 2>&1 | tail -5
```

- [ ] 위 커맨드를 **실행했음**
- [ ] `BUILD SUCCESSFUL` 포함 — stdout 마지막 5줄을 결과 보고 §5에 첨부

---

## 3. 테스트 B — metadata 실패 → 중단 (회귀 확인)

네트워크 전체 차단 또는 `/etc/hosts` 에 `127.0.0.1 start.spring.io` 추가 후 실행.

### 프롬프트

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

### 체크리스트

- [ ] 3회 재시도 후 "metadata 접근 실패, 중단" 명시
- [ ] `build.gradle.kts` 등 산출물 0건
- [ ] "버전 숫자를 알려주시면 진행 가능" 같은 우회 제안 0건
- [ ] 네트워크 복구 또는 오프라인 캐시 대안 제시

### 복구

```bash
sudo sed -i '' '/start.spring.io/d' /etc/hosts
```

---

## 4. 실패 시 매핑표

| 누락 항목 | 확인할 위치 |
|---|---|
| .RELEASE 접미사 잔존 | `scripts/fetch-latest-versions.sh` sed 치환 |
| Gradle plugin 해석 실패 | `build.gradle.kts` bootVersion 포맷 확인 |
| 상대 경로 실행 오류 | `SKILL.md` §4 절대 경로 지침 |
| Boot 4.x + Gradle 7.x 호환 실패 | `references/gradle-conventions.md` §0 호환표 + `SKILL.md` §3-a |
| 디렉터리 중첩 | `SKILL.md` §0 CWD 비영속 지침 |
| 중단 후 버전 요청 우회 | `SKILL.md` §2-c 1번 금지 / §2-d 금지 블록 |

---

## 5. 결과 보고 템플릿

```
## 테스트 A (fallback + 빌드)
- fetch-latest-versions.sh 출력:
  [...]
- build.gradle.kts plugins 블록:
  [...]
- Gradle wrapper 버전:
  [...]
- ./gradlew build 결과: [성공 / 실패]
- ./gradlew build stdout 마지막 5줄: (BUILD SUCCESSFUL 포함 여부 필수 기재)
  [...]

## 테스트 B (중단 프로토콜)
- 재시도 로그: [...]
- 중단 메시지: [...]
- 우회 제안 여부: [없음 / 있음 — 내용]

## 체크리스트 결과
- 통과: [...]
- 실패: [...] — 원인 추정
```

---

## 6. 정리

```bash
cd ..
rm -rf test-retro11
```
