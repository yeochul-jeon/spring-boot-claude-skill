# Package Structure

`apply-package-structure.sh` 가 생성하는 디렉터리 트리와 각 위치의 책임.
base package 예: `com.example.orderapi` (`com/example/orderapi`).

---

## 1) Layered

```
src/main/java/com/example/orderapi/
├── OrderApiApplication.java
├── controller/      # @RestController. HTTP ↔ DTO 변환만
├── service/         # @Service. 비즈니스 흐름 오케스트레이션
├── repository/      # @Repository. JPA/MyBatis 인터페이스
├── domain/          # Entity, VO
├── dto/             # Request/Response DTO (record 권장)
└── config/          # @Configuration, @Bean
src/test/java/com/example/orderapi/
```

**주의**
- `controller` 는 `service` 만 의존
- `service` 는 `repository`, `domain` 의존
- `controller` → `repository` 직접 호출 **금지**
- DTO 와 Entity 는 반드시 분리

---

## 2) Hexagonal (Ports & Adapters)

```
src/main/java/com/example/orderapi/
├── OrderApiApplication.java
├── domain/                      # POJO. 프레임워크 의존 제로
├── application/
│   ├── port/
│   │   ├── in/                  # UseCase 인터페이스 (inbound)
│   │   └── out/                 # Repository/ExternalClient 인터페이스 (outbound)
│   └── service/                 # Port 구현 (@Service)
├── adapter/
│   ├── in/
│   │   └── web/                 # @RestController → port.in 호출
│   └── out/
│       └── persistence/         # JPA/MyBatis → port.out 구현
└── config/
```

**주의**
- `domain` 은 `org.springframework.*` import 금지
- `application.service` 는 Port 만 의존
- Adapter 만 프레임워크(JPA, Spring Web)에 의존

---

## 3) Clean

```
src/main/java/com/example/orderapi/
├── OrderApiApplication.java
├── domain/                      # Entity, VO, Domain Service
├── application/
│   ├── usecase/                 # UseCase 구현 (1 유즈케이스 = 1 클래스)
│   └── port/                    # Repository/ExternalClient 인터페이스
├── infrastructure/
│   ├── persistence/             # JPA/MyBatis, 캐시, 외부 저장소
│   └── config/                  # @Configuration
└── presentation/
    └── web/                     # @RestController, Request/Response DTO
```

**주의**
- 의존 방향: `presentation` → `application` → `domain`
- `infrastructure` 는 `application.port` 를 구현 (의존성 역전)
- `domain` 은 모든 층의 안쪽. 아무것도 의존하지 않음

---

## 공통 권장 사항

- **base package 하위에 `OrderApiApplication.java`** 를 둬서 컴포넌트 스캔이 전체 트리를 커버하게 한다.
- 테스트 트리는 메인과 **동일한 패키지 구조**.
- 스타일 간 혼용 금지. 프로젝트 전체가 한 스타일이어야 한다.
- 다만 **MVP → 확장** 은 허용: Layered 로 시작해서 복잡도가 오르면 Hexagonal 로 리팩터링.
