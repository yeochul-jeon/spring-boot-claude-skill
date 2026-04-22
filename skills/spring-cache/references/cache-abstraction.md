# Spring Cache 추상화

## 1) 핵심 어노테이션

| 어노테이션 | 역할 |
|-----------|------|
| `@Cacheable` | 캐시 히트 시 메서드 실행 생략, 미스 시 실행 후 저장 |
| `@CachePut` | 항상 메서드 실행 후 결과를 캐시에 저장 (캐시 갱신) |
| `@CacheEvict` | 캐시 항목 삭제 |
| `@Caching` | 여러 어노테이션 조합 |

## 2) @Cacheable key SpEL 표현식

```java
// 단순 파라미터
@Cacheable(value = "products", key = "#id")
ProductResponse findById(Long id) { ... }

// 복합 키
@Cacheable(value = "products", key = "#category + ':' + #page")
List<ProductResponse> findByCategory(String category, int page) { ... }

// 조건부 캐시 (null 반환은 캐시하지 않음)
@Cacheable(value = "products", key = "#id", unless = "#result == null")
ProductResponse findById(Long id) { ... }

// 조건부 적용 (VIP 회원만 캐시)
@Cacheable(value = "orders", key = "#memberId", condition = "#memberId > 0")
List<OrderResponse> findOrders(Long memberId) { ... }
```

**key 표현식 없이 기본 키 사용은 금지** — 파라미터 수/타입 변경 시 의도치 않은 충돌 발생.

## 3) 동기 캐시 (Cache Miss Stampede 방지)

```java
@Cacheable(value = "products", key = "#id", sync = true)
ProductResponse findById(Long id) { ... }
```

동일 키로 동시 캐시 미스 발생 시 하나의 스레드만 실제 조회 실행. 나머지는 대기.

## 4) @CachePut vs @CacheEvict 선택

| 선택 | 사용 시점 |
|------|-----------|
| `@CachePut` | 수정 후 최신 값을 즉시 캐시에 반영해야 할 때 |
| `@CacheEvict` | 수정 후 다음 조회 시 DB에서 새로 가져오게 할 때 (지연 갱신 허용) |
| `@CacheEvict(allEntries=true)` | 관련 키 패턴이 복잡해 개별 삭제가 불가할 때 |

## 5) @Caching — 복합 적용

```java
@Caching(
    put  = @CachePut(value = "products", key = "#result.id()"),
    evict = @CacheEvict(value = "productList", allEntries = true)
)
@Transactional
ProductResponse update(Long id, ProductUpdateRequest request) { ... }
```
