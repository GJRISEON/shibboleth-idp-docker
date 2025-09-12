# Grafana - Loki 연동 가이드

## 🔗 Loki 데이터소스 추가

### 1. Grafana 접속
- URL: `https://idp.kwu.ac.kr:443` (Grafana가 설치된 경우)
- 또는 별도 Grafana 서버에서 접근

### 2. Loki 데이터소스 설정
1. **Configuration > Data Sources** 메뉴 접속
2. **Add data source** 클릭
3. **Loki** 선택
4. 다음 설정값 입력:

```
Name: Shibboleth-Loki
URL: https://idp.kwu.ac.kr/loki-api
```

### 3. 고급 설정 (선택사항)
```
HTTP Method: GET
Timeout: 60s

# 인증이 필요한 경우
Basic Auth: (사용 안함)

# HTTP Headers (필요시)
X-Custom-Header: your-value
```

### 4. 연결 테스트
- **Save & Test** 클릭
- ✅ "Data source connected and labels found" 메시지 확인

## 📊 즉시 사용 가능한 쿼리

### 기본 모니터링 쿼리
```logql
# 현재 수집 중인 모든 로그
{job=~"shibboleth-.*"}

# 인증 로그만 조회
{job="shibboleth-audit"}

# 에러 로그 모니터링
{job="shibboleth-warn", level="ERROR"}

# 특정 사용자 로그인 기록
{job="shibboleth-audit", principal="사용자ID"}
```

### 통계 쿼리
```logql
# 시간당 로그인 횟수
sum(count_over_time({job="shibboleth-audit"}[1h]))

# 서비스별 이용 현황
sum by (relying_party) (count_over_time({job="shibboleth-audit"}[24h]))

# 사용자별 활동
topk(10, sum by (principal) (count_over_time({job="shibboleth-audit"}[24h])))
```

## 🎨 대시보드 생성

### 1. 기본 대시보드 임포트
- **Dashboard > Import** 메뉴 접속
- 파일 업로드: `/home/ubuntu/idp5/data/loki/grafana-dashboard-shibboleth.json`

### 2. 커스텀 패널 생성

#### 로그인 횟수 패널 (Stat)
```logql
sum(count_over_time({job="shibboleth-audit", result="success"}[24h]))
```

#### 실시간 로그 패널 (Logs)
```logql
{job="shibboleth-audit"} | line_format "{{.structured_message}}"
```

#### 시간별 추이 패널 (Time Series)
```logql
sum(rate({job="shibboleth-audit"}[5m])) * 300
```

## 🚨 알림 설정

### 1. Alert Rule 생성
```logql
# 로그인 실패율 5% 초과 시 알림
(
  sum(rate({job="shibboleth-audit", result="failure"}[5m])) /
  sum(rate({job="shibboleth-audit"}[5m]))
) > 0.05
```

### 2. 알림 채널 설정
- **Alerting > Notification channels**
- Email, Slack, Teams 등 연동 가능

## 📱 모바일 접근

### Grafana 모바일 앱
- iOS/Android Grafana 앱 설치
- 서버 URL: `https://idp.kwu.ac.kr`
- 로그인 후 대시보드 확인

## 🔧 성능 최적화

### 쿼리 최적화 팁
1. **시간 범위 제한**: 너무 긴 기간 쿼리 피하기
2. **라벨 필터링**: `{job="shibboleth-audit"}` 먼저 적용
3. **집계 함수 활용**: `sum()`, `count_over_time()` 적극 사용

### 대시보드 성능
```logql
# ❌ 느린 쿼리
{job=~".*"} |= "user"

# ✅ 빠른 쿼리  
{job="shibboleth-audit", principal="user123"}
```

## 🌐 외부 접근 설정

현재 NGINX 설정으로 다음 URL들이 사용 가능합니다:

```bash
# Loki API (직접 접근)
https://idp.kwu.ac.kr/loki-api/ready
https://idp.kwu.ac.kr/loki-api/loki/api/v1/query

# Grafana에서 사용할 데이터소스 URL
https://idp.kwu.ac.kr/loki-api
```

## 🔒 보안 고려사항

### 1. 인증 추가 (권장)
```nginx
# NGINX 설정에 Basic Auth 추가
location /loki-api/ {
    auth_basic "Loki API Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    # ... 기존 설정
}
```

### 2. IP 제한 (선택사항)
```nginx
location /loki-api/ {
    allow 192.168.1.0/24;  # 내부 네트워크만 허용
    deny all;
    # ... 기존 설정
}
```

---

**🎉 이제 Grafana에서 HTTPS를 통해 안전하게 Loki 데이터에 접근할 수 있습니다!**