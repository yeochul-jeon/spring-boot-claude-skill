# MyBatis 패턴 가이드

MyBatis를 선택했을 때 따라야 할 설정, Mapper 인터페이스, XML, Dynamic SQL, ResultMap 표준.  
DTO ↔ 도메인 분리는 `spring-principles/templates/dto-entity-separation.md` 참조.

---

## 1) 설정

`application.yml` 기본 설정:

```yaml
mybatis:
  mapper-locations: classpath:mapper/**/*.xml
  type-aliases-package: com.example.myapp.domain
  configuration:
    map-underscore-to-camel-case: true   # DB: user_name → Java: userName 자동 매핑
    default-fetch-size: 100
    default-statement-timeout: 30
```

`@MapperScan`으로 Mapper 인터페이스를 일괄 등록:

```java
@SpringBootApplication
@MapperScan("com.example.myapp.mapper")
public class Application { ... }
```

> `@MapperScan` 대신 각 인터페이스에 `@Mapper`를 붙여도 동작하지만,
> 스캔 경로를 한 곳에서 관리하는 `@MapperScan`이 유지보수에 유리하다.

---

## 2) Mapper 인터페이스 규약

```java
// com.example.myapp.mapper.MemberMapper
public interface MemberMapper {

    Optional<Member> findById(Long id);

    List<Member> findAll(MemberSearchCondition condition);

    void insert(Member member);

    void update(Member member);

    void deleteById(Long id);
}
```

**규약**

| 항목 | 규칙 |
|---|---|
| 네이밍 | `find*`, `insert`, `update`, `delete*` |
| 반환 타입 | 단건: `Optional<T>`, 목록: `List<T>`, 변경: `void` 또는 `int`(영향 행 수) |
| 파라미터 | 단일 파라미터 또는 DTO/조건 객체. `@Param`은 다중 파라미터일 때만 사용 |
| 인터페이스 위치 | `mapper` 패키지, XML은 `resources/mapper/` 아래 동일 이름 |

---

## 3) XML vs 애너테이션 선택 기준

| 상황 | 권장 |
|---|---|
| 동적 SQL (`<if>`, `<foreach>`) | **XML** |
| 복잡한 `<resultMap>` (association, collection) | **XML** |
| 단순 단건 조회 / 삽입 | 애너테이션 허용 (`@Select`, `@Insert`) |

**규칙: Java 소스 안에서 SQL 문자열을 직접 조립하지 않는다.**  
`StringBuilder`로 SQL을 만드는 코드는 XML의 `<if>`/`<choose>`로 이전한다.

---

## 4) XML 기본 구조

`resources/mapper/MemberMapper.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="com.example.myapp.mapper.MemberMapper">

    <resultMap id="memberResultMap" type="Member">
        <id property="id" column="id"/>
        <result property="email" column="email"/>
        <result property="createdAt" column="created_at"/>
    </resultMap>

    <select id="findById" resultMap="memberResultMap">
        SELECT id, email, created_at
        FROM members
        WHERE id = #{id}
    </select>

    <select id="findAll" resultMap="memberResultMap">
        SELECT id, email, created_at
        FROM members
        <where>
            <if test="email != null and email != ''">
                AND email LIKE CONCAT('%', #{email}, '%')
            </if>
            <if test="active != null">
                AND active = #{active}
            </if>
        </where>
        ORDER BY created_at DESC
    </select>

    <insert id="insert" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO members (email, password, created_at)
        VALUES (#{email}, #{password}, NOW())
    </insert>

</mapper>
```

---

## 5) ResultMap — 연관 매핑

단순 컬럼 매핑은 `map-underscore-to-camel-case: true`로 충분하다.  
`<association>` (1:1)과 `<collection>` (1:N)은 ResultMap으로 명시한다.

```xml
<resultMap id="orderResultMap" type="Order">
    <id property="id" column="order_id"/>
    <result property="status" column="status"/>

    <!-- 1:1 연관 -->
    <association property="member" javaType="Member">
        <id property="id" column="member_id"/>
        <result property="email" column="member_email"/>
    </association>

    <!-- 1:N 연관 -->
    <collection property="items" ofType="OrderItem">
        <id property="id" column="item_id"/>
        <result property="productName" column="product_name"/>
        <result property="quantity" column="quantity"/>
    </collection>
</resultMap>

<select id="findWithItems" resultMap="orderResultMap">
    SELECT o.id AS order_id, o.status,
           m.id AS member_id, m.email AS member_email,
           i.id AS item_id, i.product_name, i.quantity
    FROM orders o
    JOIN members m ON o.member_id = m.id
    LEFT JOIN order_items i ON i.order_id = o.id
    WHERE o.id = #{orderId}
</select>
```

---

## 6) Dynamic SQL

**`<if>` — 선택적 조건**

```xml
<where>
    <if test="status != null">AND status = #{status}</if>
    <if test="startDate != null">AND created_at >= #{startDate}</if>
</where>
```

**`<choose>` — switch/case**

```xml
<choose>
    <when test="sortBy == 'price'">ORDER BY price DESC</when>
    <when test="sortBy == 'date'">ORDER BY created_at DESC</when>
    <otherwise>ORDER BY id DESC</otherwise>
</choose>
```

**`<foreach>` — IN 절**

```xml
<select id="findByIds" resultMap="memberResultMap">
    SELECT * FROM members
    WHERE id IN
    <foreach collection="ids" item="id" open="(" separator="," close=")">
        #{id}
    </foreach>
</select>
```

**안티패턴 — Java에서 SQL 조립 금지**

```java
// 금지: Java에서 SQL 문자열 조립
String sql = "SELECT * FROM members WHERE 1=1";
if (email != null) sql += " AND email = '" + email + "'";  // SQL 인젝션 위험

// 권장: XML의 <if> 사용
```

---

## 7) DTO 직접 매핑 전략

Mapper가 반환하는 객체는 **조회 전용 DTO**를 사용하는 것이 안전하다.  
Service에서 도메인 객체로 변환하거나, 컨트롤러 응답 DTO로 직접 변환한다.

```java
// 조회 전용 DTO (Query Object)
public record MemberRow(Long id, String email, LocalDateTime createdAt) {}

// Mapper
List<MemberRow> findAll(MemberSearchCondition condition);

// Service에서 도메인 변환
public List<MemberResponse> findAll(MemberSearchCondition condition) {
    return memberMapper.findAll(condition).stream()
        .map(row -> new MemberResponse(row.id(), row.email()))
        .toList();
}
```

---

## 요약 체크리스트

- [ ] `map-underscore-to-camel-case: true` 설정
- [ ] Mapper XML이 `resources/mapper/` 아래, 인터페이스와 이름 일치
- [ ] 동적 SQL은 XML `<if>`/`<choose>`/`<foreach>` 사용, Java 문자열 조립 없음
- [ ] 연관 매핑에 `<resultMap>` 사용 (하드코딩된 컬럼 별칭 최소화)
- [ ] `useGeneratedKeys="true" keyProperty="id"` 로 자동 생성 키 반환
- [ ] Mapper가 Entity 직접 반환 시 DTO 분리 여부 검토
