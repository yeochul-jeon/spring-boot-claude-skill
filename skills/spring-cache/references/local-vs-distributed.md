# 로컬 vs 분산 캐시 선택 기준

## 1) 선택 체크리스트

| 질문 | Yes → | No → |
|------|-------|------|
| 애플리케이션이 다중 인스턴스로 실행되는가? | Redis | Caffeine 고려 |
| 인스턴스 간 캐시 일관성이 필요한가? | Redis | Caffeine |
| 캐시 항목이 수십 MB 이상인가? | Redis | Caffeine |
| Redis 인프라 운영이 가능한가? | Redis | Caffeine |

## 2) Caffeine (로컬 캐시)

```java
@Bean
public CacheManager cacheManager() {
    CaffeineCacheManager manager = new CaffeineCacheManager("products", "members");
    manager.setCaffeine(Caffeine.newBuilder()
        .expireAfterWrite(Duration.ofMinutes(10))
        .maximumSize(1000)
        .recordStats());    // 캐시 히트율 모니터링
    return manager;
}
```

- JVM 내 메모리 → 외부 네트워크 비용 없음
- 인스턴스 재시작 시 캐시 소실
- **다중 인스턴스에서 캐시 불일치 발생** — 단일 인스턴스 또는 읽기 전용 캐시에만 사용

## 3) Redis (분산 캐시)

```java
@Bean
public RedisCacheManager cacheManager(RedisConnectionFactory factory) {
    Map<String, RedisCacheConfiguration> configs = Map.of(
        "products", ttl(Duration.ofMinutes(10)),
        "members",  ttl(Duration.ofHours(1))
    );
    return RedisCacheManager.builder(factory)
        .cacheDefaults(ttl(Duration.ofMinutes(5)))
        .withInitialCacheConfigurations(configs)
        .build();
}

private RedisCacheConfiguration ttl(Duration ttl) {
    return RedisCacheConfiguration.defaultCacheConfig()
        .entryTtl(ttl)
        .disableCachingNullValues()
        .serializeValuesWith(RedisSerializationContext.SerializationPair
            .fromSerializer(new GenericJackson2JsonRedisSerializer()));
}
```

- 인스턴스 간 공유 → 일관성 보장
- 직렬화 비용 발생 → `GenericJackson2JsonRedisSerializer` 사용 시 DTO에 기본 생성자 필요
- Redis 연결 장애 시 서비스 영향 → `RedisCacheWriter.nonLockingRedisCacheWriter` + 오류 핸들러 고려

## 4) 혼합 전략 (L1/L2 캐시)

고성능 요건 시 Caffeine(L1) + Redis(L2) 조합:
- L1 미스 → L2 조회 → L2 미스 → DB 조회
- 구현 복잡도가 높으므로 실측 병목 확인 후 적용

## 5) 개발/테스트 환경

`application-test.yml`:

```yaml
spring:
  cache:
    type: none   # 테스트에서 캐시 비활성화
```

캐시 로직을 단위 테스트할 때는 `@SpringBootTest` + `CacheManager` mock 사용.
