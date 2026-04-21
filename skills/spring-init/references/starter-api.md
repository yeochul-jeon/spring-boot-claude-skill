# start.spring.io API

프로젝트 생성에 필요한 두 엔드포인트와 주요 파라미터를 정리한다.
**버전 숫자를 본 문서에 박지 않는다** — 실제 값은 항상 API 응답에서 가져온다.

## 1) GET /metadata/client

최신 버전 정보 조회. `fetch-latest-versions.sh` 가 호출한다.

```bash
curl -sfL https://start.spring.io/metadata/client
```

주요 응답 필드:

| 경로 | 의미 |
|---|---|
| `.bootVersion.default` | 현재 권장 Spring Boot 버전 |
| `.bootVersion.values[].id` | 선택 가능한 Boot 버전 목록 |
| `.javaVersion.default` | 기본 Java 버전 |
| `.javaVersion.values[].id` | 선택 가능한 Java 버전 |
| `.dependencies.values[].values[].id` | 선택 가능한 의존성 id |
| `.type.values[].id` | 빌드 타입 (`gradle-project-kotlin` 등) |

실패 시: 네트워크 오류 → stderr 에러, exit 1. 임의 fallback 금지.

## 2) POST /starter.zip

실제 프로젝트 ZIP 생성. `generate-project.sh` 가 호출한다.

```bash
curl -sfL https://start.spring.io/starter.zip \
  -d "type=gradle-project-kotlin" \
  -d "language=java" \
  -d "bootVersion=$BOOT_VERSION" \
  -d "groupId=com.example" \
  -d "artifactId=$ARTIFACT" \
  -d "name=$ARTIFACT" \
  -d "packageName=$PKG_NAME" \
  -d "packaging=jar" \
  -d "javaVersion=$JAVA_VER" \
  -d "dependencies=$DEPS" \
  -o project.zip
```

### 파라미터 표

| 키 | 값 예 | 비고 |
|---|---|---|
| `type` | `gradle-project-kotlin` | Kotlin DSL 기본 |
| `language` | `java` | |
| `bootVersion` | 동적 (fetch 결과) | **하드코딩 금지** |
| `groupId` | `com.example` | 사용자 지정 시 덮어씀 |
| `artifactId` | `order-api` | kebab-case |
| `name` | `order-api` | artifactId 와 동일 권장 |
| `packageName` | `com.example.orderapi` | 하이픈/언더스코어 제거 |
| `packaging` | `jar` | 기본 |
| `javaVersion` | `21` | CLAUDE.md 기본값 |
| `dependencies` | CSV 문자열 | 아래 id 표 참조 |

## 3) dependency id 매핑

| 카테고리 | id | 용도 |
|---|---|---|
| Web | `web` | Spring Web MVC (항상 포함) |
| Web | `webflux` | 리액티브 (필요 시) |
| Ops | `actuator` | Health/Metrics (항상 포함) |
| Validation | `validation` | Jakarta Bean Validation (항상 포함) |
| SQL | `data-jpa` | Spring Data JPA |
| SQL | `mybatis` | MyBatis Starter |
| SQL | `mysql` | **MySQL 드라이버 (기본 권장)** |
| SQL | `postgresql` | PostgreSQL 드라이버 |
| SQL | `h2` | 테스트용 인메모리 DB |
| SQL | `flyway` | 마이그레이션 |
| Security | `security` | Spring Security |
| Security | `oauth2-resource-server` | JWT resource server |
| Test | `testcontainers` | 통합 테스트 컨테이너 |
| Observability | `prometheus` | Micrometer Prometheus |
| Dev | `lombok` | 보일러플레이트 감소 (선택) |
| Dev | `devtools` | 자동 재시작 (선택) |

## 4) 권장 조합 예시

- **최소 REST**: `web,actuator,validation`
- **JPA + MySQL**: `web,actuator,validation,data-jpa,mysql,flyway`
- **MyBatis + MySQL**: `web,actuator,validation,mybatis,mysql,flyway`
- **JPA + PostgreSQL**: `web,actuator,validation,data-jpa,postgresql,flyway`
- **Secured JPA**: `web,actuator,validation,security,data-jpa,mysql`
- **통합 테스트 포함**: 위 조합 + `testcontainers`

## 5) 예외 처리 원칙

- API 호출 실패 → 사용자에게 알리고 **중단**
- 스크립트에 `set -euo pipefail` 필수
- 임의 버전 추정·fallback 금지 (이 스킬 세트의 존재 이유)
