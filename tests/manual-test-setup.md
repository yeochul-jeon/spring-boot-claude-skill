# 수동 테스트 실행 가이드

`tests/cases.md`의 케이스들을 실제 Claude Code 세션에서 실행하는 절차.
스킬 개발 컨텍스트에 오염되지 않도록 **별도 디렉터리 + 새 세션**에서 수행한다.

---

## 왜 분리하는가

각 케이스는 "스킬이 제대로 동작하는가"를 검증한다.
현재 프로젝트(`spring-boot-claude-skill`)에서 실행하면
이 프로젝트의 `CLAUDE.md`(스킬 개발 지침)가 함께 로드되어 결과가 오염된다.

따라서 스킬이 독립적으로 trigger되고 현실적인 결과를 내는지 보려면
**깨끗한 테스트 프로젝트**에서 실행해야 한다.

---

## 스킬 인식 경로

Claude Code는 두 위치에서 스킬을 로드한다.

| 위치 | 범위 | 용도 |
|---|---|---|
| `~/.claude/skills/` | 전역 (모든 프로젝트) | 전역 오염 위험 — 테스트에 부적합 |
| `<project>/.claude/skills/` | 해당 프로젝트만 | **테스트에 권장** |

---

## 테스트 프로젝트 준비

### 1. 테스트 디렉터리 생성

```bash
mkdir -p ~/github/test-spring-security
```

케이스별로 디렉터리를 다르게 준비해도 되고, 재사용해도 된다
(재사용 시 `.claude/skills/`만 남기고 매번 비우기).

### 2. `.claude/skills/` 생성

```bash
mkdir -p ~/github/test-spring-security/.claude/skills
```

### 3. 6개 스킬을 symlink

복사 대신 symlink를 쓰면 원본 스킬 수정 시 자동 동기화된다.

```bash
cd ~/github/test-spring-security/.claude/skills

ln -s ~/github/spring-boot-claude-skill/skills/spring-init        spring-init
ln -s ~/github/spring-boot-claude-skill/skills/spring-principles  spring-principles
ln -s ~/github/spring-boot-claude-skill/skills/spring-web         spring-web
ln -s ~/github/spring-boot-claude-skill/skills/spring-persistence spring-persistence
ln -s ~/github/spring-boot-claude-skill/skills/spring-security    spring-security
ln -s ~/github/spring-boot-claude-skill/skills/spring-testing     spring-testing
```

### 4. 확인

```bash
ls -la ~/github/test-spring-security/.claude/skills/
```

6개 symlink가 `->` 로 원본 경로를 가리키면 성공.

---

## 왜 6개 전부 설치하는가

특정 케이스는 한 스킬이 주 대상이지만, 실제 프롬프트는 여러 스킬을 연쇄 호출한다.
일부만 설치하면 스킬 간 참조 경로가 깨져 현실적이지 않은 결과가 나온다.

예: 케이스 5("로그인 있는 REST API 프로젝트 만들어")

| 스킬 | 호출 이유 |
|---|---|
| `spring-init` | 프로젝트 스캐폴딩 + 아키텍처 결정 |
| `spring-principles` | 자가 검증 체크리스트 |
| `spring-web` | REST Controller 패턴 |
| `spring-security` | **메인 검증 대상** |
| `spring-persistence` | Member 엔티티 저장 (선택적) |
| `spring-testing` | 테스트 코드 생성 (선택적) |

---

## 테스트 실행

```bash
cd ~/github/test-spring-security
claude
```

새 세션에서 `tests/cases.md`의 프롬프트를 입력한다.

### 케이스별 프롬프트

| 케이스 | 프롬프트 |
|---|---|
| 1 | `Spring Boot 최신 버전으로 간단한 Hello World REST API 프로젝트 만들어줘` |
| 2 | `상품 주문 도메인 REST API 프로젝트 시작해줘` |
| 3 | `PostgreSQL 연동하는 회원 CRUD 프로젝트 만들어` |
| 4 | `간단한 회원 가입 Controller, Service, Repository 만들어줘` |
| 5 | `로그인 있는 REST API 프로젝트 만들어` |

---

## 검증 방법

각 케이스는 `tests/cases.md`에 체크리스트가 있다.
Claude의 응답과 생성된 파일을 기준으로 항목별 PASS/FAIL을 기록한다.

### 예: 케이스 5 체크

- [ ] 세션 vs JWT 선택 질문이 나왔는가
  - 프롬프트에 명시가 없으므로 반드시 물어봐야 함
  - 물어보지 않고 임의 선택했다면 **실패**
- [ ] BCrypt 기본, DelegatingPasswordEncoder 사용
  - 생성된 `SecurityConfig`에서 `PasswordEncoderFactories.createDelegatingPasswordEncoder()`
    또는 `BCryptPasswordEncoder` 확인
- [ ] CORS 설정 포함
  - `CorsConfigurationSource` Bean 생성
  - `allowedOrigins`가 환경변수·설정값으로 주입되는지 확인

### 버전 하드코딩 회귀 검사 (모든 케이스 공통)

```bash
cd ~/github/test-spring-security
grep -rE '"[0-9]+\.[0-9]+\.[0-9]+"' build.gradle.kts src/
```

구체적인 Spring Boot 버전 숫자(예: `3.5.3`)가 박혀 있으면 **케이스 1 회귀 실패**.

---

## 결과 기록

`tests/cases.md` 하단의 "실행 결과 기록" 표에 추가한다.

```markdown
| 2026-04-22 | 5 | PASS/FAIL | 비고 |
```

FAIL이면 원인을 비고에 남기고 해당 스킬의 SKILL.md 또는 references/를 수정 후 재실행.

---

## 테스트 후 정리

```bash
# 옵션 1: 스킬만 제거 (테스트 프로젝트 보존)
rm -rf ~/github/test-spring-security/.claude/skills

# 옵션 2: 테스트 디렉터리 전체 삭제
rm -rf ~/github/test-spring-security
```

symlink를 제거해도 원본 스킬 파일은 안전하다.

---

## 트러블슈팅

### 스킬이 trigger되지 않음

1. `ls -la ~/github/test-spring-security/.claude/skills/` — symlink가 깨지지 않았는지 확인
2. 각 스킬의 `SKILL.md` 프론트매터 `description` 필드에 trigger 키워드가 있는지 확인
3. 새 세션을 완전히 재시작 (`/clear`가 아닌 `claude` 재실행)

### 여러 스킬이 서로 참조 안 됨

스킬 내부에서 `spring-principles/SKILL.md` 같은 상대 경로를 참조하는데,
6개가 같은 `.claude/skills/` 안에 있으면 정상 동작한다.
일부만 설치하면 참조가 끊어지므로 **6개 모두 설치** 원칙을 지킨다.
