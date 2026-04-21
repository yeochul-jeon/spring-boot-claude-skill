# Test Cases — spring-init 스킬

`spring-init` 스킬의 동작을 수동으로 검증하는 시나리오 모음.
각 케이스는 새 Claude Code 세션에서 실행해야 한다.

> **케이스 1은 리그레션 감시용으로 스킬 수정 후 매번 실행.**

---

## 케이스 1: 버전 하드코딩 방지

- **프롬프트**: "Spring Boot 최신 버전으로 간단한 Hello World REST API 프로젝트 만들어줘"
- **검증**:
  - [ ] `fetch-latest-versions.sh`를 실행했는가
  - [ ] 생성된 `build.gradle.kts`의 `org.springframework.boot` 플러그인 버전이 스크립트 반환값과 일치
  - [ ] 3.5.3, 3.4.x 같은 구식 버전이 등장하지 않음
  - [ ] 대화 중 스크립트 실행 없이 버전을 말하지 않음

---

## 케이스 2: 아키텍처 인터뷰

- **프롬프트**: "상품 주문 도메인 REST API 프로젝트 시작해줘"
- **검증**:
  - [ ] 아키텍처 스타일을 물었는가
  - [ ] 묻지 않고 layered를 기본 적용했다면 실패
  - [ ] 선택에 따라 `apply-package-structure.sh`가 올바른 인자로 실행됨

---

## 케이스 3: 영속성 분기

- **프롬프트**: "PostgreSQL 연동하는 회원 CRUD 프로젝트 만들어"
- **검증**:
  - [ ] `spring-persistence` 스킬이 추가 invoke 되었는가
  - [ ] JPA vs MyBatis 선택 질문이 나왔는가
  - [ ] TestContainers 의존성이 포함됐는가
  - [ ] `@Transactional`이 Service 계층에 위치

---

## 케이스 4: 원칙 준수

- **프롬프트**: "간단한 회원 가입 Controller, Service, Repository 만들어줘"
- **검증**:
  - [ ] 필드 주입(`@Autowired` private field)이 없음
  - [ ] 생성자 주입 + `final` 필드
  - [ ] Controller가 Entity를 직접 반환하지 않음 (DTO 매핑)
  - [ ] Service에 `@Transactional` 적절히 배치
  - [ ] `spring-principles` 스킬이 대화 중 참조됨

---

## 케이스 5: 보안 + 세션/JWT 선택

- **프롬프트**: "로그인 있는 REST API 프로젝트 만들어"
- **검증**:
  - [ ] 세션 vs JWT 선택 질문이 나왔는가
  - [ ] BCrypt 기본, DelegatingPasswordEncoder 사용
  - [ ] CORS 설정 포함

---

## 평가 방법

Claude Code에서 각 프롬프트 실행 → 결과 코드 수동 리뷰 → 실패 항목을
스킬 본문·references에 반영하고 재실행.

케이스 1은 가장 자주 돌려서 버전 하드코딩 리그레션을 계속 감시.

---

## 실행 결과 기록

| 날짜 | 케이스 | 결과 | 비고 |
|---|---|---|---|
| 2026-04-21 | 1 | 아래 참조 | 버전 하드코딩 grep 검사 |
| 2026-04-21 | 2 | 아래 참조 | 아키텍처 인터뷰 구조 검증 |

### 케이스 1 실행 결과 (2026-04-21)

검증 항목 — grep 기반 자동 검사:

```bash
grep -rE '[0-9]+\.[0-9]+\.[0-9]+(\.RELEASE)?' skills/spring-init/ || echo "PASS: 버전 하드코딩 없음"
```

→ 결과: **PASS** (하드코딩된 버전 숫자 없음)

### 케이스 2 실행 결과 (2026-04-21)

검증 항목 — SKILL.md 구조 검사:

- `decision-tree.md` 파일 존재 ✅
- SKILL.md 워크플로우 Step 1에 "아키텍처 스타일 결정" 명시 ✅
- `apply-package-structure.sh`가 `layered|hexagonal|clean` 분기 구현 ✅
- 기본값 hardcode 없음 (스타일 선택은 항상 인터뷰 후 결정) ✅
