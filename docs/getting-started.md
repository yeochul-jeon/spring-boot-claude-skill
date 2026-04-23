# Getting Started — spring-boot-claude-skill

## 이 프로젝트는 무엇인가

Claude Code 세션에 연결하면 자연어 프롬프트 한 줄로 Spring Boot 프로젝트를 생성·확장할 수 있는 **스킬 세트**다.

- 버전 하드코딩 없음 — `start.spring.io` 메타데이터 API 를 실시간 조회해 최신 Boot 버전 사용
- 아키텍처 인터뷰 — Layered / Hexagonal / Clean 중 Q1~Q5 점수제로 추천·승인
- 원칙 자가검증 — 생성자 주입·DTO 분리·Rich domain 등 체크리스트를 코드 작성 직후 자동 검증

---

## 사전 준비

- [ ] Claude Code CLI 설치 확인 — `claude --version`
- [ ] 인터넷 연결 (`start.spring.io` 호출 필요)
- [ ] Java 21 + Gradle (생성된 프로젝트를 실행할 때만 필요)

---

## 5분 설치

```bash
# 1. 저장소 클론
git clone https://github.com/<your-org>/spring-boot-claude-skill.git

# 2. 사용할 프로젝트 디렉터리로 이동
cd my-spring-project
mkdir -p .claude

# 3. 스킬 심볼릭 링크 연결
ln -s ../../spring-boot-claude-skill/skills .claude/skills

# 4. Claude Code 실행
claude
```

> **확인**: Claude Code 내에서 `/skills` 라고 입력하면 연결된 스킬 목록이 표시돼야 한다.
> 목록에 `spring-init` 이 없다면 심볼릭 링크 경로를 다시 확인한다.

---

## 첫 프롬프트 3종

### Level 1 — Hello World REST API

```
Spring Boot 로 Hello World REST API 만들어줘
```

**기대 동작**
1. `fetch-latest-versions.sh` 실행 → start.spring.io 에서 최신 Boot 버전 조회
2. 도메인 힌트("Hello World", "간단한")가 충분하면 아키텍처 질문 자동 추론 후 확인만 요청
3. `build.gradle.kts` + `src/` scaffold 생성

**관전 포인트**: 생성된 `build.gradle.kts` 의 `org.springframework.boot` 플러그인 버전이 API 조회값과 일치하는지

---

### Level 2 — 회원 CRUD (JPA + PostgreSQL)

```
PostgreSQL 로 회원 CRUD REST API 만들어줘
```

**기대 동작**
1. `spring-init` → `spring-web` + `spring-persistence` + `spring-principles` 자동 결합
2. JPA vs MyBatis 선택 질문 → JPA 선택 시 `Member` Entity + `MemberRepository` + `MemberService` + `MemberController` 생성

**관전 포인트**
- 생성자 주입 + `final` 필드 (필드 `@Autowired` 없음)
- `Member` Entity 가 Controller 응답으로 직접 반환되지 않음 (`MemberResponse` DTO 분리)
- `@Transactional` 이 Service 계층에 위치

---

### Level 3 — JWT 로그인

```
JWT 로그인 있는 REST API 프로젝트 만들어줘
```

**기대 동작**
1. `spring-security` 스킬 발동 → 세션 vs JWT 선택 질문
2. JWT 선택 시 `JwtTokenProvider` + `SecurityConfig` + BCrypt 기본 설정 생성

**관전 포인트**
- `DelegatingPasswordEncoder` 사용 여부
- CORS 설정 포함 여부

---

## 결과 검증 (smoke test)

Level 1~3 완료 후 아래 명령으로 버전 하드코딩 여부를 확인한다:

```bash
# 생성된 프로젝트 루트에서 실행
grep -rE '[0-9]+\.[0-9]+\.[0-9]+(\.RELEASE)?' build.gradle.kts
# 결과가 없으면 PASS (버전이 동적 조회됨)
```

> 더 상세한 회귀 검증은 [`tests/cases.md`](../tests/cases.md) 케이스 1~8 과
> [`tests/regression-22-meta-expanded.md`](../tests/regression-22-meta-expanded.md) §A 참조.

---

## 자주 막히는 곳 FAQ

**Q. 스킬이 인식되지 않아요**
`.claude/skills` 심볼릭 링크가 실제 `skills/` 디렉터리를 가리키는지 확인한다.
```bash
ls -la .claude/skills   # → spring-init, spring-web 등이 보여야 함
```

**Q. `fetch-latest-versions.sh` 가 실패해요**
네트워크 또는 프록시 문제다. `curl -s https://start.spring.io/metadata/client` 를 직접 실행해 응답이 오는지 확인한다.

**Q. 아키텍처 인터뷰 질문이 매번 5개씩 다 떠요**
프롬프트에 힌트를 추가하면 자동 추론 후 확인만 요청한다.
- "간단한", "CRUD", "Hello World" → Layered 자동 추론
- 힌트 없이 "REST API" 만 입력하면 Q1~Q5 전체 진행

**Q. 생성된 `build.gradle.kts` 에 구식 버전이 박혀있어요**
버전 하드코딩 리그레션이다. [`tests/cases.md`](../tests/cases.md) 케이스 1 의 grep 명령을 스킬 디렉터리에 실행해 오염 경로를 찾는다:
```bash
grep -rE '[0-9]+\.[0-9]+\.[0-9]+(\.RELEASE)?' skills/spring-init/
```

---

## 다음 단계

| 목표 | 참조 |
|---|---|
| 10개 스킬 전체 개요 | [README.md — 스킬 목록](../README.md#스킬-목록) |
| 설계 결정 배경 (ADR) | [docs/ADR.md](ADR.md) |
| 회귀 검증 전체 목록 | [tests/cases.md](../tests/cases.md) |
| 회고 로그 (#1 ~ #29) | [docs/logs/](logs/) |
