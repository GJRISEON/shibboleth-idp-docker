# Shibboleth IdP - Loki 장기 로그온 기록 분석 쿼리 모음

## 1. 기본 인증 통계 쿼리

### 일간 로그인 성공 횟수
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="success"} 
  [1d]
))
```

### 주간 로그인 성공 횟수  
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="success"}
  [7d]
))
```

### 월간 로그인 성공 횟수
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="success"}
  [30d]
))
```

### 연간 로그인 성공 횟수
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="success"}
  [365d]
))
```

## 2. 사용자별 분석

### 월간 TOP 10 활성 사용자
```logql
topk(10, 
  sum by (principal) (
    count_over_time(
      {job="shibboleth-audit", result="success"}
      [30d]
    )
  )
)
```

### 특정 사용자의 로그인 기록 (최근 30일)
```logql
{job="shibboleth-audit", principal="user123"} |= "success"
| line_format "{{.structured_message}}"
```

### 월간 신규 사용자 수 (첫 로그인)
```logql
count by (principal) (
  first_over_time(
    {job="shibboleth-audit", result="success"}[30d]
  )
)
```

## 3. 서비스 제공자(SP)별 분석

### 월간 SP별 이용 현황
```logql
sum by (relying_party) (
  count_over_time(
    {job="shibboleth-audit", result="success"}
    [30d]
  )
)
```

### TOP 5 인기 서비스
```logql
topk(5,
  sum by (relying_party) (
    count_over_time(
      {job="shibboleth-audit", result="success"}
      [30d]
    )
  )
)
```

## 4. 시간대별 분석

### 시간대별 로그인 패턴 (24시간)
```logql
sum by (hour) (
  count_over_time(
    {job="shibboleth-audit", result="success"}
    | __timestamp__ % 86400 / 3600
    [1d]
  )
)
```

### 요일별 로그인 패턴
```logql
sum by (weekday) (
  count_over_time(
    {job="shibboleth-audit", result="success"}
    | strftime "%w" __timestamp__ as weekday
    [7d]
  )
)
```

### 월별 트렌드 (연간)
```logql
sum by (month) (
  count_over_time(
    {job="shibboleth-audit", result="success"}
    | strftime "%Y-%m" __timestamp__ as month
    [365d]
  )
)
```

## 5. 인증 방법별 분석

### 인증 방법별 통계
```logql
sum by (auth_method) (
  count_over_time(
    {job="shibboleth-audit", result="success"}
    [30d]
  )
)
```

### Password vs SSO 비율
```logql
sum by (auth_method) (
  count_over_time(
    {job="shibboleth-audit", auth_method=~"Password|SAML|OAuth", result="success"}
    [30d]
  )
)
```

## 6. 보안 분석

### 실패한 로그인 시도 (월간)
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="failure"}
  [30d]
))
```

### IP별 실패 시도 TOP 10
```logql
topk(10,
  sum by (client_address) (
    count_over_time(
      {job="shibboleth-audit", result="failure"}
      [7d]
    )
  )
)
```

### 비정상적인 로그인 패턴 감지 (같은 사용자, 다른 IP)
```logql
count by (principal) (
  count by (principal, client_address) (
    {job="shibboleth-audit", result="success"}
  ) > 1
) > 3
```

### 시간외 로그인 (주말, 야간)
```logql
{job="shibboleth-audit", result="success"}
| __timestamp__ % 86400 / 3600 < 8 or __timestamp__ % 86400 / 3600 > 18
| line_format "Off-hours login: {{.principal}} at {{.datetime}}"
```

## 7. 성능 및 오류 분석

### 인증 실패율 (일간)
```logql
(
  sum(count_over_time({job="shibboleth-audit", result="failure"}[1d])) /
  sum(count_over_time({job="shibboleth-audit"}[1d]))
) * 100
```

### 에러 로그 분석
```logql
{job="shibboleth-warn", level="ERROR"}
| line_format "{{.datetime}} {{.logger}}: {{.message}}"
```

### 응답시간 분석 (프로세스 로그에서)
```logql
{job="shibboleth-process"} 
|~ "duration|elapsed|time"
| line_format "{{.message}}"
```

## 8. 비즈니스 인텔리전스

### 월간 활성 사용자 수 (MAU)
```logql
count by () (
  count by (principal) (
    {job="shibboleth-audit", result="success"}
    [30d]
  ) > 0
)
```

### 일간 활성 사용자 수 (DAU)
```logql
count by () (
  count by (principal) (
    {job="shibboleth-audit", result="success"}
    [1d]
  ) > 0
)
```

### 사용자 유지율 (월간 재방문)
```logql
(
  count by () (
    count by (principal) (
      {job="shibboleth-audit", result="success"}
      [30d]
    ) > 1
  ) /
  count by () (
    count by (principal) (
      {job="shibboleth-audit", result="success"}  
      [30d]
    ) > 0
  )
) * 100
```

### 서비스별 월간 성장률
```logql
(
  sum by (relying_party) (
    count_over_time({job="shibboleth-audit", result="success"}[30d])
  ) -
  sum by (relying_party) (
    count_over_time({job="shibboleth-audit", result="success"}[30d] offset 30d)
  )
) / 
sum by (relying_party) (
  count_over_time({job="shibboleth-audit", result="success"}[30d] offset 30d)
) * 100

```

## 9. 운영 모니터링

### 실시간 로그인 현황 (최근 5분)
```logql
sum(count_over_time(
  {job="shibboleth-audit", result="success"}
  [5m]
))
```

### 서비스 가용성 체크
```logql
sum(count_over_time(
  {job="shibboleth-audit"}
  [1m]
)) > 0
```

### 최근 경고 및 에러
```logql
{job="shibboleth-warn", level=~"WARN|ERROR"}
| line_format "{{.level}}: {{.message}}"
```

## 10. 커스텀 알림 쿼리

### 로그인 실패율 임계값 초과 (10% 이상)
```logql
(
  sum(rate({job="shibboleth-audit", result="failure"}[5m])) /
  sum(rate({job="shibboleth-audit"}[5m]))
) > 0.1
```

### 특정 IP에서 연속 실패 (5회 이상)
```logql
sum by (client_address) (
  count_over_time(
    {job="shibboleth-audit", result="failure"}
    [10m]
  )
) > 5
```

### 시스템 오류 급증 감지
```logql
increase(
  sum(count_over_time({job="shibboleth-warn", level="ERROR"}[5m]))
) > 10
```