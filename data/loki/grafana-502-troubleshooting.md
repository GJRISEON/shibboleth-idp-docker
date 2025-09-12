# Grafana 502 Bad Gateway 해결 가이드

## 🔍 현재 상황 분석
- ✅ 쉘에서 curl 명령어로는 정상 접근 가능
- ❌ Grafana UI에서 502 Bad Gateway 에러 발생

## 🛠️ 해결 방법

### 1. Grafana 데이터소스 설정 확인

#### A. 기본 설정
```
Name: Shibboleth-Loki
Type: Loki
URL: https://idp.kwu.ac.kr/loki-api
```

#### B. HTTP 설정 (중요!)
```
HTTP Method: GET
Timeout: 60s

✅ Skip TLS Verify: 체크 (자체 서명 인증서인 경우)
✅ With Credentials: 체크 해제
✅ With CA Cert: 비워두기
```

### 2. Grafana 설정 파일 수정 (grafana.ini)

```ini
[security]
# TLS 검증 비활성화 (개발/테스트 환경)
tls_skip_verify_insecure = true

[auth.anonymous]
# 필요시 익명 접근 허용
enabled = true

[server]
# Grafana 서버 설정
protocol = https
cert_file = /path/to/cert.pem
cert_key = /path/to/cert.key
```

### 3. Grafana Docker 환경변수 설정

```yaml
# docker-compose.yml에서 Grafana 서비스
grafana:
  image: grafana/grafana:latest
  environment:
    - GF_SECURITY_TLS_SKIP_VERIFY_INSECURE=true
    - GF_LOG_LEVEL=debug
  volumes:
    - grafana-storage:/var/lib/grafana
```

### 4. 네트워크 연결 확인

#### Grafana 컨테이너에서 직접 테스트
```bash
# Grafana 컨테이너 접속
docker exec -it <grafana_container> /bin/bash

# 내부에서 Loki 접근 테스트
curl -k "https://idp.kwu.ac.kr/loki-api/ready"
curl -k "https://idp.kwu.ac.kr/loki-api/loki/api/v1/labels"
```

### 5. 대안 설정 (로컬 접근)

#### A. 내부 네트워크 사용
Grafana가 같은 Docker 네트워크에 있다면:
```
URL: http://loki:3100
```

#### B. 포트 포워딩 추가
docker-compose.yml에서 Loki 포트 노출:
```yaml
loki:
  ports:
    - "3100:3100"  # 추가
```
그리고 Grafana에서:
```
URL: http://localhost:3100
```

### 6. NGINX 로그 확인

```bash
# NGINX 에러 로그 확인
docker-compose exec nginx cat /var/log/nginx/error.log

# 실시간 로그 모니터링
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

### 7. Grafana 로그 확인

```bash
# Grafana 로그에서 상세 에러 확인
docker logs <grafana_container> 2>&1 | grep -i loki
docker logs <grafana_container> 2>&1 | grep -i "502\|gateway\|proxy"
```

## 🚨 즉시 시도해볼 해결책

### 해결책 1: TLS 검증 비활성화
Grafana 데이터소스 설정에서:
- **Skip TLS Verify**: ✅ 체크
- **TLS Auth**: 비활성화

### 해결책 2: HTTP 사용
NGINX에 HTTP도 프록시 추가:
```nginx
# HTTP 버전도 추가
server {
    listen 80;
    location /loki-api/ {
        proxy_pass http://loki_backend/;
    }
}
```

### 해결책 3: 직접 연결
docker-compose.yml에서:
```yaml
loki:
  ports:
    - "3100:3100"
```
Grafana 데이터소스:
```
URL: http://idp.kwu.ac.kr:3100
```

## 📞 디버깅 명령어

```bash
# 1. Grafana에서 실제로 시도하는 URL 확인
docker logs <grafana_container> --tail 50

# 2. NGINX 실시간 로그
docker-compose logs -f nginx

# 3. Loki 상태 확인
curl -k "https://idp.kwu.ac.kr/loki-api/ready"

# 4. 네트워크 연결 확인
docker network ls
docker network inspect <network_name>
```

---

**💡 가장 가능성 높은 해결책: Grafana 데이터소스 설정에서 "Skip TLS Verify" 체크하기**