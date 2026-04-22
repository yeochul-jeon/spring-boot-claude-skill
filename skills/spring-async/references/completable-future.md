# @Async + CompletableFuture 패턴

## 1) @Async 기본

```java
@Service
public class NotificationService {

    // void 반환 — fire-and-forget
    @Async
    public void sendPushNotification(Long userId, String message) {
        // 발송 로직
    }

    // CompletableFuture 반환 — 결과 추적 가능
    @Async
    public CompletableFuture<NotificationResult> sendEmail(String to, String subject) {
        NotificationResult result = emailClient.send(to, subject);
        return CompletableFuture.completedFuture(result);
    }
}
```

**`@Async` 메서드 반환 타입은 `void` 또는 `CompletableFuture<T>` 만 허용.** // 금지: 다른 타입
`String`, `Integer` 등 일반 타입 반환 시 비동기 프록시가 적용되지 않는다.

## 2) 예외 처리

```java
// 단일 예외 처리
notificationService.sendEmail(to, subject)
    .exceptionally(ex -> {
        log.error("이메일 발송 실패: {}", ex.getMessage());
        return NotificationResult.failed();
    });

// 성공/실패 모두 처리
notificationService.sendEmail(to, subject)
    .handle((result, ex) -> {
        if (ex != null) {
            log.error("실패: {}", ex.getMessage());
            return NotificationResult.failed();
        }
        return result;
    });
```

`thenApply` / `thenAccept` 체인에서 발생한 예외는 caller에게 전파되지 않는다 — 반드시 `exceptionally` 또는 `handle` 로 처리.

## 3) 병렬 실행 조합

```java
// 여러 비동기 작업 병렬 실행 후 모두 완료 대기
CompletableFuture<ProductResponse> productFuture = productService.findAsync(productId);
CompletableFuture<StockResponse> stockFuture = stockService.findAsync(productId);

CompletableFuture.allOf(productFuture, stockFuture)
    .thenApply(v -> {
        ProductResponse product = productFuture.join();
        StockResponse stock = stockFuture.join();
        return ProductDetailResponse.of(product, stock);
    })
    .exceptionally(ex -> {
        log.error("상품 상세 조회 실패", ex);
        return ProductDetailResponse.empty();
    });
```

## 4) 타임아웃 설정

```java
notificationService.sendEmail(to, subject)
    .orTimeout(5, TimeUnit.SECONDS)    // Java 9+
    .exceptionally(ex -> {
        if (ex instanceof TimeoutException) {
            log.warn("이메일 발송 타임아웃");
        }
        return NotificationResult.failed();
    });
```

## 5) @Async 내부 호출 금지

```java
@Service
public class OrderService {

    // 금지 패턴 — 같은 클래스 내부 호출은 프록시를 우회해 @Async 미적용 // 금지
    public void createOrder(OrderCreateRequest request) {
        sendNotification(request.memberId());   // @Async 무시됨
    }

    @Async
    public void sendNotification(Long memberId) { ... }
}
```

해결책: 알림을 별도 `NotificationService` Bean으로 분리.
