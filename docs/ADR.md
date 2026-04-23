# Architecture Decision Records

## 철학

버전·아키텍처를 절대 가정하지 않는다.
동적 조회와 사용자 승인으로 모델의 과거 지식을 무력화한다.
항상 작동하는 최소 구현을 선택하고, 단순하게 시작해 필요할 때 진화한다.

---

## ADR-001: Skill 구조 — 주제별 분리 (6개)

결정: `spring-init`, `spring-principles`, `spring-web`, `spring-persistence`, `spring-security`, `spring-testing` 6개 스킬로 분리.

이유: 점진적 로딩 — 사용자가 필요한 스킬만 컨텍스트에 로드할 수 있다. 유지보수 범위가 명확히 나뉜다.

트레이드오프: 스킬 간 cross-reference 관리 비용 발생. `spring-principles`가 모든 스킬의 의존점이므로 반드시 두 번째로 구현해야 한다.

---

## ADR-002: Spring Boot 버전 동적 조회

결정: `start.spring.io/metadata/client` API를 `fetch-latest-versions.sh`로 호출해 버전을 런타임에 얻는다. 스킬 파일 내 버전 숫자 하드코딩 금지.

이유: LLM 학습 시점 종속 제거. 학습 데이터 컷오프 이후 출시된 버전을 자동으로 사용할 수 있다.

트레이드오프: 오프라인 환경에서 동작 불가. 단, fallback 버전 추정 대신 명시적 실패(exit 1)를 선택해 잘못된 버전 생성보다 낫다는 판단.

---

## ADR-003: 아키텍처 결정 트리 (Q1~Q5 점수제)

결정: 5개 질문(도메인 복잡도, 외부 통합, 수명, 팀 규모, 테스트 요구)에 점수를 매겨 Layered / Hexagonal / Clean 중 추천. 동점 시 더 단순한 쪽 우선(Layered > Hexagonal > Clean).

이유: YAGNI — 단순한 구조에서 시작해 필요할 때 진화. 의사결정을 투명하게 사용자에게 보여주고 최종 승인을 받는다.

트레이드오프: 단순 프롬프트에도 질문 오버헤드가 생긴다. 프롬프트 추론 스킵 규칙(충분한 힌트가 있으면 질문 생략)으로 완화.

---

## ADR-004: Phase B/C 스킬 확장 (6 → 10)

결정: 운영·확장 축 4개 스킬(`spring-batch`, `spring-cache`, `spring-observability`, `spring-async`) 신설.

이유: 초기 6개 스킬은 scaffolding + CRUD 축에 편중됐다. 실무 Spring 애플리케이션에서 빈번히 필요한 배치/캐시/관찰가능성/비동기 축이 누락되어 있었다.

트레이드오프: 스킬 cross-reference 그래프 복잡도 증가. `spring-principles` 가 10개 전부에 참조되는 구조는 유지되므로 원칙 일관성은 보존. 신규 4개 스킬은 F–J 설계-먼저 방식이 아닌 empirical BASELINE 사이클(retro #23~#26)로 구축. 관련 로그: `docs/logs/log-20260423-retro22.md` ~ `retro26.md`.

---

## ADR-005: grep-based §A meta-regression (자기참조 자동 검증)

결정: `tests/regression-22-meta-expanded.md` 에 10개 스킬 × 3~5 규칙(총 38개)의 grep 블록을 유지하고, 스킬 SKILL.md 수정 시마다 재실행한다.

이유: SKILL.md 수정 중 실수로 자기 규칙을 위반하는 패턴(`@Autowired` 필드 주입 예시, 버전 하드코딩 등)을 조기에 탐지한다. 수동 리뷰만으로는 전수 확인이 어렵다.

트레이드오프: grep 의 구조적 한계 — 목차·다이어그램 라인, 부정 문장("사용 금지")도 "존재함"으로 오인할 수 있다. 이 known-limitation 3건(A7b/A7c/A8c/A9c)은 주석으로 명시하고 empirical BASELINE 사이클로 보완한다. 관련 로그: retro #22, #27~#29.

---

## ADR-006: Codex adversarial review 를 empirical 사이클 표준 단계로 편입

결정: 스킬 empirical 사이클의 공식 단계를 다음으로 정의한다: BASELINE → 2차 회전 → §A meta-regression 확장 → **Codex adversarial review 1회 패스**.

이유: retro #27 §A 확장 커밋 직후 Codex 리뷰에서 High 0 / Medium 8 / Low 8 지적이 발견됐다. 정적 grep FP/FN 이 자체 리뷰만으로 드러나지 않음을 확인했다. 한 차례 외부 관점 검토로 문서 심사 품질을 정량화할 수 있다.

트레이드오프: 1회 추가 검토 비용 발생. 대신 Medium 이슈 전건을 패치해 false-negative 0건 달성 가능. 관련 로그: retro #28 (medium 8건 패치), retro #29 (low 5건 패치 + known-limitation 3건 명시).
