# 템플릿 메서드 패턴 변환

## Before

```java
// 동일한 try-catch-finally 구조가 반복됨
@Component
public class ExternalApiCaller {

    public ProductDto fetchProduct(Long id) {
        log.info("API 호출 시작: fetchProduct({})", id);
        try {
            // 실제 HTTP 호출
            return httpClient.get("/products/" + id, ProductDto.class);
        } catch (HttpClientErrorException e) {
            log.error("API 오류: {}", e.getMessage());
            throw new ExternalApiException("상품 조회 실패", e);
        } finally {
            log.info("API 호출 종료: fetchProduct");
        }
    }

    public OrderDto fetchOrder(Long id) {
        log.info("API 호출 시작: fetchOrder({})", id);
        try {
            return httpClient.get("/orders/" + id, OrderDto.class);
        } catch (HttpClientErrorException e) {
            log.error("API 오류: {}", e.getMessage());
            throw new ExternalApiException("주문 조회 실패", e);
        } finally {
            log.info("API 호출 종료: fetchOrder");
        }
    }
}
```

## After

```java
// 템플릿 메서드로 횡단 관심사 추출
@Component
public abstract class ExternalApiTemplate {

    protected <T> T execute(String operationName, Supplier<T> apiCall) {
        log.info("API 호출 시작: {}", operationName);
        try {
            return apiCall.get();
        } catch (HttpClientErrorException e) {
            log.error("API 오류 [{}]: {}", operationName, e.getMessage());
            throw new ExternalApiException(operationName + " 실패", e);
        } finally {
            log.info("API 호출 종료: {}", operationName);
        }
    }
}

@Component
public class ExternalApiCaller extends ExternalApiTemplate {

    public ProductDto fetchProduct(Long id) {
        return execute("fetchProduct", () ->
            httpClient.get("/products/" + id, ProductDto.class));
    }

    public OrderDto fetchOrder(Long id) {
        return execute("fetchOrder", () ->
            httpClient.get("/orders/" + id, OrderDto.class));
    }
}
```

## 왜

반복 try-catch-finally는 횡단 관심사(로깅, 예외 변환)가 비즈니스 로직에 뒤섞인 신호다. 템플릿 메서드나 전략 패턴으로 추출하면 새로운 API 호출 추가 시 중복 없이 같은 정책이 자동 적용되고, 정책 변경 시 한 곳만 수정하면 된다.

## 관련 원칙

- [references/separation-of-concerns.md](../references/separation-of-concerns.md) — 횡단 관심사 분리
- [references/testability.md](../references/testability.md) — `execute` 단독 단위 테스트 가능
