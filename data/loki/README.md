# Shibboleth IdP - Loki 장기 로그온 기록 시스템 구축 가이드

## 🎯 개요

본 시스템은 Shibboleth IdP의 인증 로그를 Loki에 수집하여 장기간 보관하고 분석할 수 있는 솔루션입니다.

## 📋 주요 특징

- **장기 보존**: 1년 이상 로그 데이터 보관 (설정 가능)
- **구조화된 로그**: Audit 로그를 파싱하여 필터링 및 검색 최적화
- **실시간 모니터링**: Grafana 대시보드를 통한 실시간 현황 파악
- **보안 분석**: 실패한 로그인 시도, 비정상 패턴 감지
- **비즈니스 인텔리전스**: 사용자 활동, 서비스 이용 현황 분석

## 🏗️ 시스템 구조

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Shibboleth IdP │────│    Promtail     │────│      Loki       │
│                 │    │  (Log Shipper)  │    │ (Long-term DB)  │
│  audit logs     │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                              ┌─────────────────┐    │
                              │     Grafana     │────┘
                              │   (Dashboard)   │
                              └─────────────────┘
```

## 🚀 배포 방법

### 1. 기존 환경에 배포

```bash
# idp5 디렉토리로 이동
cd /home/ubuntu/idp5

# 컨테이너 시작
docker-compose up -d loki promtail

# 로그 확인
docker-compose logs -f promtail
docker-compose logs -f loki
```

### 2. 전체 시스템 재시작

```bash
# 전체 서비스 재시작 (IdP 포함)
docker-compose down
docker-compose up -d

# 상태 확인
docker-compose ps
```

## 📊 데이터 확인

### Loki 직접 쿼리

```bash
# Loki API를 통한 직접 쿼리
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="shibboleth-audit"}' \
  --data-urlencode 'limit=10'
```

### Grafana에서 확인

1. Grafana 접속: http://localhost:3000 (설정된 경우)
2. Data Source 추가: Loki (http://loki:3100)
3. Dashboard Import: `/home/ubuntu/idp5/data/loki/grafana-dashboard-shibboleth.json`

## 📈 주요 분석 쿼리

### 기본 통계
- 일간/주간/월간 로그인 횟수
- 로그인 성공률
- 활성 사용자 수 (DAU/MAU)

### 사용자 분석
- TOP 활성 사용자
- 신규 사용자 추이
- 사용자별 로그인 패턴

### 서비스 분석
- 서비스별 이용 현황
- 인기 서비스 TOP 5
- 서비스별 성장률

### 보안 분석
- 로그인 실패 시도
- 의심스러운 IP 추적
- 비정상 시간대 로그인

## 🔧 설정 파일 설명

### 1. Loki 설정 (`data/loki/loki-config.yml`)

```yaml
# 주요 설정값
retention_period: 8760h          # 1년 보존
max_query_length: 8760h          # 1년 범위 쿼리 허용
compaction_interval: 10m         # 10분마다 압축
retention_enabled: true          # 자동 삭제 활성화
```

### 2. Promtail 설정 (`data/promtail/promtail-config.yml`)

```yaml
# 수집 대상 로그 파일들
- /var/log/shibboleth/idp-audit.log    # 인증 이벤트 (주요)
- /var/log/shibboleth/idp-process.log  # 처리 로그
- /var/log/shibboleth/idp-warn.log     # 경고/에러
```

### 3. Shibboleth 로깅 설정

- `overlay/shibboleth-idp-custom/conf/logback.xml`: 로그 레벨 및 파일 분리
- `overlay/shibboleth-idp-custom/conf/audit.properties`: Audit 로깅 활성화

## 📚 LogQL 쿼리 가이드

상세한 쿼리 예시는 `/home/ubuntu/idp5/data/loki/logql-queries-guide.md` 참조

### 자주 사용하는 쿼리

```logql
# 오늘 로그인 횟수
sum(count_over_time({job="shibboleth-audit", result="success"}[1d]))

# TOP 10 활성 사용자 (월간)
topk(10, sum by (principal) (count_over_time({job="shibboleth-audit", result="success"}[30d])))

# 특정 사용자 로그인 기록
{job="shibboleth-audit", principal="사용자ID"} |= "success"

# 로그인 실패 시도
{job="shibboleth-audit", result="failure"} | line_format "{{.principal}} from {{.client_address}}"
```

## 🚨 알림 설정 (권장)

### 1. 높은 실패율 알림
```logql
(sum(rate({job="shibboleth-audit", result="failure"}[5m])) / sum(rate({job="shibboleth-audit"}[5m]))) > 0.1
```

### 2. 연속 실패 시도 감지
```logql
sum by (client_address) (count_over_time({job="shibboleth-audit", result="failure"}[10m])) > 5
```

### 3. 시스템 오류 급증
```logql
increase(sum(count_over_time({job="shibboleth-warn", level="ERROR"}[5m]))) > 10
```

## 🔧 성능 최적화

### 1. 스토리지 최적화
- 압축률 높음: 텍스트 로그는 90% 이상 압축 가능
- 인덱싱 최적화: 주요 라벨만 인덱싱하여 저장 공간 절약

### 2. 쿼리 성능
- 시간 범위 제한: 너무 긴 기간 쿼리 시 성능 저하
- 라벨 필터링: `{job="shibboleth-audit"}` 먼저 적용 후 추가 필터링

### 3. 리소스 사용량
- Memory: Loki 컨테이너에 최소 1GB RAM 할당 권장
- Disk: 압축 후 일일 약 100MB~1GB (로그인 양에 따라)

## 📞 문제 해결

### 1. 로그가 수집되지 않는 경우
```bash
# Promtail 상태 확인
docker-compose logs promtail

# 로그 파일 권한 확인
docker exec -it monitoring_promtail ls -la /var/log/shibboleth/

# Loki 연결 확인
curl http://localhost:3100/ready
```

### 2. 쿼리가 느린 경우
- 시간 범위를 줄여서 테스트
- 라벨 필터링을 먼저 적용
- Loki 메모리 할당량 증가

### 3. 디스크 공간 부족
- Retention 기간 단축 (8760h → 4380h)
- 오래된 압축 파일 수동 삭제
- Compaction 주기 단축

## 🎓 교육 및 학습

### 추천 학습 순서
1. LogQL 기본 문법 학습
2. Grafana 대시보드 생성 실습
3. 알림 규칙 설정
4. 성능 튜닝 실습

### 유용한 참고 자료
- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [LogQL Tutorial](https://grafana.com/docs/loki/latest/logql/)
- [Shibboleth IdP Audit Logging](https://wiki.shibboleth.net/confluence/display/IDP4/AuditLoggingConfiguration)

---

**이 시스템으로 광주여자대학교의 장기 로그온 기록을 안전하고 효율적으로 관리하실 수 있습니다!** 🎓✨