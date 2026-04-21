# Architecture Styles

`decision-tree.md` 가 추천한 스타일의 **구현 세부**를 설명한다.
세 스타일(Layered / Hexagonal / Clean)의 언제/왜/구조/트레이드오프.

---

## Layered

### 언제 쓰나

- CRUD 중심, 비즈니스 규칙이 단순
- 프로토타입, 1년 미만 단기 프로젝트
- 1~2인 팀
- 해피패스 테스트 중심

### 구조 특징

- 위→아래 단방향 의존: `controller → service → repository → DB`
- 각 계층은 다음 계층만 안다
- Domain 객체는 JPA Entity 와 겸용하는 경우가 흔함 (단, DTO-Entity 분리는 유지)

### 장점

- 진입장벽 낮음. Spring 표준 예제와 동일
- 작은 코드베이스에서 오버엔지니어링 없음
- 프레임워크와 밀접해도 단기 비용 저렴

### 단점

- 도메인 로직이 Service로 누출되기 쉬움 (Anemic Domain 경향)
- 영속성 기술(JPA/MyBatis)이 도메인에 스며듬
- 복잡해지면 Service 비대 → 리팩터링 비용 큼

### 탈출 신호

- Service 클래스가 500줄+
- Controller가 Repository를 직접 호출
- 트랜잭션 경계가 불분명
→ Hexagonal 로 진화 고려

---

## Hexagonal (Ports & Adapters)

### 언제 쓰나

- 일부 비즈니스 규칙 존재 (상태 전이, 권한 정책 등)
- 외부 통합 2~3개 (DB + 외부 API + 메시징 등)
- 1~3년 수명
- 단위+통합 테스트 체계 필요

### 구조 특징

- **Domain**: 프레임워크 의존성 제로. POJO.
- **Application**: Use case 오케스트레이션. Port 정의.
  - `port/in`: 들어오는 요청 인터페이스 (UseCase)
  - `port/out`: 나가는 의존성 인터페이스 (Repository, ExternalClient)
  - `service`: Port 구현 (Application Service)
- **Adapter**: Port 의 구체 구현.
  - `adapter/in/web`: REST Controller → Port/in 호출
  - `adapter/out/persistence`: JPA/MyBatis → Port/out 구현

### 장점

- 도메인이 프레임워크와 격리 → 순수 단위 테스트 쉬움
- 외부 기술(DB, 메시징) 교체 비용이 낮음
- Port 덕분에 테스트 더블(Fake/Mock) 작성이 명확

### 단점

- 파일·패키지 수 증가
- CRUD만 하는 엔드포인트에도 Port 한 쌍이 필요 → 오버헤드
- 팀이 의도를 이해하지 못하면 "Layered + 인터페이스 과다" 로 전락

### 핵심 규칙

- Domain 은 `org.springframework.*` import 금지
- Application Service 는 `@Service` 만, JPA/HTTP 의존 금지
- Adapter 만 프레임워크에 닿음

---

## Clean Architecture

### 언제 쓰나

- 복잡한 도메인 규칙 (다수 invariant, 정책, 전략)
- 외부 통합 4개+ (메시징, 외부 API, 캐시, 검색 등)
- 5년+ 장기 유지보수
- 6인+ 팀
- 규제·장애 대응으로 고커버리지 필수

### 구조 특징

- 동심원 4층. **의존성은 항상 안쪽으로**.
  - `domain` (Entity, VO, Domain Service) — 가장 안쪽
  - `application` (UseCase, Port) — 비즈니스 흐름
  - `infrastructure` (Persistence, Config, External) — 구체 구현
  - `presentation` (Web Controller, GraphQL 등)
- Hexagonal 의 엄격한 버전. Use Case 가 1급 개념.

### 장점

- 도메인이 가장 보호됨. 기술 변경에 강함
- Use Case 단위로 테스트·문서화 가능
- 대규모 팀에서 경계가 명확 → 병렬 개발

### 단점

- 디렉터리·파일 수 가장 많음
- Simple CRUD 에는 과잉. 팀이 규율 못 지키면 Layered 보다 복잡만 증가
- 교육 비용 큼

### Hexagonal 과의 차이

- Hexagonal: Port 중심. 그 외 층 구분은 느슨.
- Clean: 4층을 엄격히 구분. Use Case 객체를 명시적으로 정의.

---

## 선택 원칙 요약

1. `decision-tree.md` 의 점수로 **추천**
2. **동점 시 더 단순한 쪽**: Layered > Hexagonal > Clean (YAGNI)
3. 사용자 최종 승인
4. 선택된 스타일의 디렉터리 트리는 `package-structure.md` 참조
