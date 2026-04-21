# REST Conventions

## 1) URL 네이밍

| 규칙 | 예시 |
|---|---|
| 명사 복수 | `/members`, `/orders`, `/order-items` |
| kebab-case | `/order-items` (camelCase 금지) |
| 동사 금지 | `/members/{id}` — DELETE 메서드로 표현 (~~`/deleteMember/{id}`~~) |
| 계층 관계 | `/orders/{orderId}/items` (항목이 주문에 속할 때) |
| 버전 접두사 | `/api/v1/members` |

## 2) HTTP 메서드 사용 기준

| 메서드 | 용도 | 멱등성 | 응답 본문 |
|---|---|---|---|
| `GET` | 조회 | ✅ | 있음 |
| `POST` | 생성, 복잡한 조회(긴 쿼리) | ❌ | 있음 (생성 리소스) |
| `PUT` | 전체 교체 | ✅ | 있음 또는 없음 |
| `PATCH` | 부분 수정 | ❌ | 있음 또는 없음 |
| `DELETE` | 삭제 | ✅ | 없음 (`204`) |

**언제 PUT vs PATCH**
- 필드 일부만 수정(예: 이름만 변경) → `PATCH`
- 리소스 전체를 새 값으로 교체 → `PUT`

## 3) 상태 코드 매핑표

| 코드 | 의미 | 사용 시점 |
|---|---|---|
| `200 OK` | 성공 (일반 조회·수정) | `GET`, `PUT`, `PATCH` 성공 |
| `201 Created` | 생성 성공 | `POST`로 리소스 생성 시. `Location` 헤더 권장 |
| `204 No Content` | 성공, 본문 없음 | `DELETE`, 콘텐츠 없는 `PUT`/`PATCH` |
| `400 Bad Request` | 요청 형식 오류 | Bean Validation 실패, 파싱 오류 |
| `401 Unauthorized` | 인증 없음 | 토큰 없거나 만료 |
| `403 Forbidden` | 권한 없음 | 인증은 됐지만 접근 불가 |
| `404 Not Found` | 리소스 없음 | 존재하지 않는 ID |
| `409 Conflict` | 중복·충돌 | 이미 존재하는 이메일, 낙관적 락 충돌 |
| `422 Unprocessable Entity` | 비즈니스 규칙 위반 | 입력 형식은 맞지만 도메인 규칙 위반 |
| `500 Internal Server Error` | 서버 오류 | 예측 못한 예외 (클라이언트에 상세 노출 금지) |

## 4) 컬렉션 vs 단일 항목 URL 패턴

```
GET    /members          → 목록 조회
POST   /members          → 생성
GET    /members/{id}     → 단일 조회
PUT    /members/{id}     → 전체 수정
PATCH  /members/{id}     → 부분 수정
DELETE /members/{id}     → 삭제
```

중첩 리소스:
```
GET  /orders/{orderId}/items          → 주문 내 항목 목록
POST /orders/{orderId}/items          → 주문에 항목 추가
GET  /orders/{orderId}/items/{itemId} → 특정 항목 조회
```

## 5) 페이지네이션 쿼리 규약

Spring Data 기본 파라미터 사용:

```
GET /members?page=0&size=20&sort=createdAt,desc
```

| 파라미터 | 설명 | 기본값 |
|---|---|---|
| `page` | 0-indexed 페이지 번호 | 0 |
| `size` | 페이지 크기 | 20 |
| `sort` | 필드명,방향 | createdAt,desc |

응답 구조 (`Page<T>` 그대로 반환하지 말고 DTO로 감쌈):
```json
{
  "content": [...],
  "page": 0,
  "size": 20,
  "totalElements": 100,
  "totalPages": 5,
  "last": false
}
```

## 관련 원칙

- [dto-patterns.md](./dto-patterns.md) — 응답 DTO 구조
- [exception-handling.md](./exception-handling.md) — 상태 코드별 예외 매핑
