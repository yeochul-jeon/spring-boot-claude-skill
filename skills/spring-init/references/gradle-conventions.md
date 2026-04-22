# Gradle Conventions (Kotlin DSL)

`start.spring.io` 가 생성한 `build.gradle.kts` 를 수정할 때 따를 규약.
**Spring Boot 버전 숫자를 본 파일·프로젝트 문서·스크립트 결과 어디에도 박지 않는다.**

---

## 0) Boot ↔ Gradle 최소 버전 호환표

| Spring Boot | 최소 Gradle | 비고 |
|-------------|-------------|------|
| 3.x | 7.5+ | Gradle 7.5.1 로컬 설치로 충분 |
| 4.x | 8.4+ | `gradle wrapper --gradle-version 8.13` 등으로 업그레이드 |

> Gradle wrapper 는 현행 안정판을 권장한다. 고정 버전은 기입하지 않는다.
> 최신 안정판 확인: `gradle --version` (로컬 설치 기준) 또는 [gradle.org/releases](https://gradle.org/releases/).

fallback scaffold(§2-c) 또는 wrapper 갱신이 필요할 때:
```bash
cd /absolute/path/to/project && gradle wrapper --gradle-version <현행 안정판>
```

---

## 1) 플러그인 선언 순서

```kotlin
plugins {
    java
    id("org.springframework.boot") version "<bootVersion>"   // fetch-latest-versions.sh 반환값 사용
    id("io.spring.dependency-management") version "1.1.7"    // Spring Boot plugin 과 독립적인 외부 플러그인 — 버전 필수
}
```

> `io.spring.dependency-management` 는 Spring Boot Gradle plugin 번들이 아니므로
> 버전을 생략하면 Gradle plugin portal 조회가 실패한다. 현행 안정판: `1.1.7`.

**규칙**:
- 플러그인 블록은 파일 최상단
- `org.springframework.boot` 버전은 `fetch-latest-versions.sh` 반환값만 사용
- `io.spring.dependency-management` 버전은 명시적으로 기입 (`1.1.7` 또는 현행 안정판)
- 절대 Java 코드나 application.yml 에 버전을 복제하지 않는다

---

## 2) Java Toolchain

```kotlin
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}
```

- 기본 Java 21 (CLAUDE.md 기준).
- Gradle 이 자동으로 JDK를 다운로드/선택 → 로컬 JDK 의존성 감소.

---

## 3) 의존성 버전 중앙화 — `libs.versions.toml`

`gradle/libs.versions.toml` 로 서드파티 버전을 한 곳에 둔다.

```toml
[versions]
testcontainers = "1.20.3"
mapstruct = "1.6.3"

[libraries]
testcontainers-mysql = { group = "org.testcontainers", name = "mysql", version.ref = "testcontainers" }
mapstruct-core = { group = "org.mapstruct", name = "mapstruct", version.ref = "mapstruct" }
mapstruct-processor = { group = "org.mapstruct", name = "mapstruct-processor", version.ref = "mapstruct" }
```

**주의**:
- Spring Boot 가 관리하는 의존성(Spring, Jackson, Logback 등)은 여기 적지 않는다.
  Boot 의 BOM 이 버전을 잡아준다.
- 직접 버전 관리할 것만 적는다 (TestContainers, MapStruct, 외부 라이브러리).

**Spring Boot major 버전별 아티팩트명** — `fetch-latest-versions.sh` 의 `bootVersion` 앞자리로 판단:

| 용도 | Boot 3.x | Boot 4.x |
|------|----------|----------|
| Servlet MVC 웹 | `spring-boot-starter-web` | `spring-boot-starter-webmvc` |
| MVC 슬라이스 테스트 | `spring-boot-starter-test` (내장) | `spring-boot-starter-webmvc-test` |
| H2 콘솔 | `spring-boot-starter-data-jpa` (자동) | `spring-boot-h2console` (별도 추가) |
| JPA 슬라이스 테스트 | `spring-boot-starter-data-jpa` (내장) | `spring-boot-starter-data-jpa-test` |
| 보안 테스트 유틸 | `spring-security-test` (내장) | `spring-boot-starter-security-test` |

아티팩트명을 확신할 수 없을 때는 `./gradlew dependencies` 로 BOM 포함 여부를 확인한다.

`build.gradle.kts` 에서 참조 (아래는 **Boot 4.x** 기준):

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-webmvc")      // Boot 3.x: spring-boot-starter-web
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    implementation(libs.mapstruct.core)
    annotationProcessor(libs.mapstruct.processor)

    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")  // Boot 3.x: spring-boot-starter-test
    testImplementation(libs.testcontainers.mysql)
}
```

**Boot 3.x 기준 예시 (3.x 팀 참조용)**:

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    implementation(libs.mapstruct.core)
    annotationProcessor(libs.mapstruct.processor)

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation(libs.testcontainers.mysql)
}
```

---

## 4) 권장 태스크 설정

```kotlin
tasks.withType<Test> {
    useJUnitPlatform()
}

tasks.withType<JavaCompile> {
    options.compilerArgs.add("-parameters")  // record/validation 용
}
```

---

## 5) 금지 사항

- `ext { springBootVersion = "..." }` 같은 전역 변수로 버전 박제 **금지**
- `implementation("org.springframework.boot:spring-boot-starter-web:X.Y.Z")` 처럼 버전 명시 **금지**
  (BOM 이 관리)
- 임의 버전 추정 fallback **금지**

---

## 6) 검증 커맨드

```bash
./gradlew build           # 컴파일 + 테스트
./gradlew bootRun         # 로컬 실행
./gradlew dependencies    # 의존성 트리 확인
```
