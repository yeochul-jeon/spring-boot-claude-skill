# 캐시 무효화 전략

## 1) TTL 설계 원칙

| 데이터 특성 | 권장 TTL |
|------------|---------|
| 거의 변경 없음 (카테고리, 코드성) | 1시간 ~ 24시간 |
| 가끔 변경 (상품 정보) | 10~30분 |
| 자주 변경 (재고, 가격) | 1~5분 또는 TTL 캐시 미사용 |
| 실시간 필요 (잔액, 포인트) | 캐시 금지 |

TTL 없는 캐시는 절대 허용하지 않는다.

## 2) @CacheEvict 타이밍

```java
// write-through: 수정 즉시 캐시 삭제
@CacheEvict(value = "products", key = "#id")
@Transactional
public ProductResponse update(Long id, ProductUpdateRequest request) { ... }

// write-behind: DB 커밋 후 캐시 삭제 (@TransactionalEventListener)
@Transactional
public ProductResponse update(Long id, ProductUpdateRequest request) {
    ProductResponse response = doUpdate(id, request);
    applicationEventPublisher.publishEvent(new ProductUpdatedEvent(id));
    return response;
}

@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
@CacheEvict(value = "products", key = "#event.productId()")
public void evictCache(ProductUpdatedEvent event) { }
```

`@TransactionalEventListener`를 사용하면 트랜잭션 롤백 시 캐시를 삭제하지 않는다.
트랜잭션 커밋 후 삭제하므로 일관성 보장.

## 3) null 캐시 정책

```java
// 안티패턴 — null 을 캐시하면 DB에 데이터가 생겨도 계속 null 반환 // 금지
@Cacheable(value = "products", key = "#id")
ProductResponse findById(Long id) { return null; }

// 올바른 패턴 — null 반환 시 캐시하지 않음
@Cacheable(value = "products", key = "#id", unless = "#result == null")
ProductResponse findById(Long id) { return null; }
```

또는 CacheManager 레벨에서 `disableCachingNullValues()` 설정.

## 4) 전체 무효화 (allEntries)

```java
// 관련 키가 너무 많을 때
@CacheEvict(value = "products", allEntries = true)
public void importProducts(List<ProductImportRequest> requests) { ... }
```

`allEntries = true` 는 분산 캐시에서도 동작하지만 Redis의 경우 `KEYS` 명령을 사용할 수 있어
대규모 키 셋에서 성능 영향이 있다. 필요 시 별도 namespace prefix + SCAN 방식 활용.

## 5) 캐시 워밍업

```java
@Component
@RequiredArgsConstructor
public class CacheWarmup implements ApplicationRunner {

    private final ProductService productService;

    @Override
    public void run(ApplicationArguments args) {
        productService.findTopCategories();   // 애플리케이션 시작 시 캐시 적재
    }
}
```
