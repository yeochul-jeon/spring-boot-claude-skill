# 회고 #9 재검증 가이드 — 아키텍처 인터뷰 + 원칙 준수

`tests/cases.md` 케이스 2(아키텍처 인터뷰)·4(원칙 준수) 가 스킬 문서만으로 자동 작동하는지
**새 Claude Code 세션**에서 확인한다. 회고 #9 에서 수정한 SB 4.x 아티팩트 + HttpStatusEntryPoint
패턴도 함께 검증한다.

> 선행 조건: `tests/manual-test-setup.md` 의 "스킬 인식 경로" 섹션을 먼저 숙지.

---

## 1. 테스트 디렉터리 준비

```bash
mkdir ../test-arch-v2 && cd ../test-arch-v2
mkdir -p .claude
ln -s ../../spring-boot-claude-skill/skills .claude/skills
claude
```

---

## 2. 테스트 A — 케이스 2: 아키텍처 인터뷰

### 프롬프트

```
상품 주문 도메인 REST API 프로젝트 시작해줘
```

### 체크리스트

**spring-init 트리거·인터뷰**
- [ ] `spring-init` 스킬이 invoke 됨
- [ ] `fetch-latest-versions.sh` 실행 흔적 존재
- [ ] `bootVersion` 앞자리 판독 후 4.x 아티팩트명(`spring-boot-starter-webmvc`) 사용
  - 3.x 이름(`spring-boot-starter-web`)이 `build.gradle.kts` 에 들어갔다면 **실패**

**아키텍처 인터뷰 (cases.md 케이스 2)**
- [ ] 아키텍처 스타일 질문이 나왔는가 (Layered / Hexagonal / Clean)
  - 묻지 않고 Layered를 바로 적용했다면 **실패**
  - 단, Q1~Q5 모두 프롬프트에서 추론 가능하다고 판단 + 근거를 제시하고 확인을 요청한 경우는 통과
- [ ] `apply-package-structure.sh` 가 선택된 아키텍처 인자로 실행됨
- [ ] 패키지 구조가 선택 스타일과 일치 (예: Layered → `controller/service/repository/domain`)

**원칙 준수 자가 검증**
- [ ] `spring-principles` 스킬 참조 또는 체크리스트 실행 흔적
- [ ] 필드 주입(`@Autowired` private field) 0건
- [ ] 생성자 주입 + `final` 필드 사용

---

## 3. 테스트 B — 케이스 4: 원칙 준수

새 디렉터리 재사용 또는 별도 `../test-principles-v2` 에서 실행.

### 프롬프트

```
간단한 회원 가입 Controller, Service, Repository 만들어줘
```

### 체크리스트

**코드 원칙 (cases.md 케이스 4)**
- [ ] 필드 주입(`@Autowired` private field) 없음
- [ ] 생성자 주입 + `final` 필드
- [ ] Controller 가 `Member` 엔티티를 직접 반환 안 함 (DTO 매핑)
- [ ] Service 에 `@Transactional` 배치 (`readOnly = true` 기본, 쓰기 메서드에 `@Transactional`)
- [ ] `spring-principles` 스킬이 대화 중 참조됨

**회고 #8·#9 패턴 재검증**
- [ ] `GlobalExceptionHandler` 가 별도 `@RestControllerAdvice` 클래스 (컨트롤러 내부 `@ExceptionHandler` 0건)
- [ ] `ProblemDetail` 반환, `pd.setProperty("errors", ...)` 키 사용 (`fieldErrors` 아님)
- [ ] `build.gradle.kts` 에 구체 버전 숫자 하드코딩 없음

---

## 4. 실패 시 매핑표

| 누락 항목 | 확인할 위치 |
|---|---|
| 아키텍처 인터뷰 없음 | `skills/spring-init/SKILL.md` §1-b 결정 트리 문구 |
| 4.x 아티팩트명 미적용 | `skills/spring-init/SKILL.md` §3 "> bootVersion..." 지시 |
| apply-package-structure.sh 미실행 | `skills/spring-init/SKILL.md` §4 |
| 필드 주입 잔존 | `skills/spring-principles/SKILL.md` 체크리스트 + `references/anti-patterns.md` §1 |
| Controller 에서 Entity 반환 | `skills/spring-principles/references/anti-patterns.md` §3 |
| @Transactional 위치 오류 | `skills/spring-principles/references/anti-patterns.md` §5 |
| 컨트롤러 내부 @ExceptionHandler | `skills/spring-web/references/exception-handling.md` 원칙 블록 |
| 3.x 아티팩트명 사용 | `skills/spring-init/references/gradle-conventions.md` §3 표·예시 |

---

## 5. 결과 보고 템플릿

```
## 테스트 A 결과 (케이스 2)
- build.gradle.kts 아티팩트 (핵심부):
  [...]
- 아키텍처 인터뷰 여부: [예/아니오, 어떤 방식으로]
- apply-package-structure.sh 실행 인자: [...]
- 패키지 구조 스냅샷:
  [...]

## 테스트 B 결과 (케이스 4)
- MemberController.java (핵심부):
  [...]
- MemberService.java (핵심부):
  [...]
- GlobalExceptionHandler.java (존재 여부 + 핵심부):
  [...]

## 체크리스트 결과
- 통과: [항목 목록]
- 실패: [항목 목록] — 원인 추정
```

이후 실패 항목은 매핑표 기반으로 해당 스킬 문서를 보강하고 회고 #10 계획을 수립한다.

---

## 6. 정리

```bash
cd ..
rm -rf test-arch-v2
```
