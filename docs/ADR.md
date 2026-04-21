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
