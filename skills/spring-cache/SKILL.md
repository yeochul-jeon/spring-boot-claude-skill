---
name: spring-cache
description: Use when adding caching to Spring Boot applications. Trigger
  on "캐시", "Cacheable", "Redis 캐시", "Caffeine", "TTL", "캐시 전략",
  "캐시 무효화". The skill asks local vs distributed cache need before
  configuring, and enforces explicit key/condition expressions and TTL.
---

# Spring Cache

Spring Boot Cache 추상화의 표준 패턴.
로컬(Caffeine) vs 분산(Redis) 선택 → TTL 설정 → 무효화 전략을 순서대로 확정하며,
코드 작성 완료 후 `spring-principles` 체크리스트로 자가 검증한다.

## 절대 원칙

1. **캐시 저장소 선택을 가정하지 않는다.** 로컬(Caffeine) vs 분산(Redis) 은 `references/local-vs-distributed.md` 기준으로 먼저 결정하고 사용자 승인을 받는다.
2. **`@Cacheable` key/condition을 항상 명시한다.** SpEL 표현식 없이 기본 키를 사용하면 메서드 시그니처 변경 시 의도치 않은 캐시 충돌이 발생한다.
3. **TTL을 반드시 설정한다.** TTL 없는 캐시는 메모리 누수와 stale 데이터의 근원이다.
4. **null 캐시 정책을 명시한다.** null 반환을 캐시하면 실제 데이터 입력 후에도 캐시 히트로 null을 반환한다.

## 워크플로우

### 1. 저장소 선택

`references/local-vs-distributed.md` 기준:

| 기준 | Caffeine (로컬) | Redis (분산) |
|------|-----------------|--------------|
| 인스턴스 수 | 단일 or 소수 | 다중 인스턴스 |
| 데이터 크기 | 수 MB 이하 | 수십 MB 이상 |
| 일관성 | 인스턴스별 독립 | 공유 |
| 운영 부담 | 없음 | Redis 인프라 필요 |

### 2. 의존성 추가

**Caffeine (로컬)**

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-cache")
    implementation("com.github.ben-manes.caffeine:caffeine")
}
```

**Redis (분산)**

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-cache")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
}
```

### 3. 캐시 설정

`references/cache-abstraction.md` 참조.

**Caffeine 설정**

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder()
            .expireAfterWrite(Duration.ofMinutes(10))
            .maximumSize(500));
        return manager;
    }
}
```

**Redis 설정**

```java
@Configuration
@EnableCaching
@RequiredArgsConstructor
public class CacheConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory factory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .disableCachingNullValues();

        return RedisCacheManager.builder(factory)
            .cacheDefaults(config)
            .build();
    }
}
```

### 4. 캐시 적용

`references/eviction-strategy.md` 참조.

```java
@Service
@RequiredArgsConstructor
public class ProductService {

    @Cacheable(value = "products", key = "#id", unless = "#result == null")
    @Transactional(readOnly = true)
    public ProductResponse findById(Long id) { ... }

    @CachePut(value = "products", key = "#result.id()")
    @Transactional
    public ProductResponse update(Long id, ProductUpdateRequest request) { ... }

    @CacheEvict(value = "products", key = "#id")
    @Transactional
    public void delete(Long id) { ... }
}
```

### 5. 자가 검증

`spring-principles/SKILL.md` 체크리스트를 실행한다.

## 작성 후 체크리스트

- [ ] 로컬(Caffeine) vs 분산(Redis) 선택을 사용자에게 확인했는가
- [ ] `@Cacheable` key 표현식 명시 (기본 키 사용 금지)
- [ ] TTL이 모든 캐시에 설정됨
- [ ] `disableCachingNullValues()` 또는 `unless = "#result == null"` 으로 null 캐시 정책 명시
- [ ] `@CacheEvict` 타이밍이 데이터 일관성 요건에 맞게 설정됨 (`allEntries` vs key 기반)
- [ ] 캐시 키 충돌 가능성 검토 (여러 메서드가 같은 캐시명 공유 시)
- [ ] `spring-principles` 체크리스트 전 항목 통과

## grep 자동 검증 패턴

`<SRC>` 는 프로젝트의 `src/main/java` 절대 경로.

```bash
# C1: @Cacheable key 미명시 (key 속성 없는 @Cacheable — 수동 확인 필요)
echo "=== [C1] @Cacheable key 명시 ==="
grep -rn "@Cacheable" <SRC>/ | grep -v 'key\s*=' | grep -v "//\|grep"
echo "(위 결과 있으면 key 표현식 확인 필요)"

# C2: @EnableCaching 설정 존재 (1건 이상이어야 PASS)
echo "=== [C2] @EnableCaching ==="
grep -rn "@EnableCaching" <SRC>/ || echo "FAIL: @EnableCaching 없음"

# C3: TTL 설정 확인 (수동 확인 필수)
# Caffeine: expireAfterWrite(TTL)/expireAfterAccess(TTI), Redis Java: entryTtl/@TimeToLive
# Redis yml: spring.cache.redis.time-to-live → resources/ 도 스캔
# 주의: grep은 TTL 문자열 존재만 확인함 — 모든 캐시에 TTL이 적용되는지는 수동으로 확인해야 함
# (기본 CacheManager TTL 이 모든 @Cacheable 캐시에 적용되는지, 또는 캐시별 TTL 이 빠진 캐시가 없는지)
echo "=== [C3] TTL 설정 ==="
grep -rn "expireAfterWrite\|expireAfterAccess\|entryTtl\|TimeToLive" <SRC>/ 2>/dev/null | head -5
grep -rn "time-to-live" <SRC>/../resources/ 2>/dev/null | head -3
echo "MANUAL: 0건이면 FAIL(TTL 없음); 1건 이상이면 @Cacheable 캐시 전체에 TTL 적용 여부를 수동으로 확인"

# C4: null 캐시 방지 설정 (1건 이상이어야 PASS)
echo "=== [C4] null 캐시 방지 ==="
grep -rn "disableCachingNullValues\|unless.*null\|unless = " <SRC>/ | head -3
echo "(위 결과 1건 이상 → PASS)"
```

## references/ 목록

| 파일 | 설명 |
|---|---|
| `cache-abstraction.md` | Spring Cache 추상화 구조, @Cacheable/@CachePut/@CacheEvict/@Caching, SpEL key 표현식 |
| `local-vs-distributed.md` | Caffeine vs Redis 선택 기준, 설정 비교, 멀티 인스턴스 일관성 |
| `eviction-strategy.md` | TTL 설계, null 캐시 정책, @CacheEvict 타이밍 (write-through vs write-around), 캐시 워밍업 |
