# GitHub Actions Workflow for IdP KWU AC KR

## 개요

이 workflow는 `idp-kwu-ac-kr` 브랜치에 코드가 푸시될 때 자동으로 Shibboleth IdP Docker 이미지를 빌드하고 `registry.bitgaram.info`에 푸시합니다.

## 설정 방법

### 1. Repository Secrets 설정

GitHub 저장소의 Settings > Secrets and variables > Actions에서 다음 secrets을 추가해야 합니다:

- `REGISTRY_USERNAME`: registry.bitgaram.info 레지스트리 사용자명
- `REGISTRY_PASSWORD`: registry.bitgaram.info 레지스트리 비밀번호

### 2. Workflow 동작

- **트리거**: `idp-kwu-ac-kr` 브랜치에 push 또는 pull request
- **빌드 인수**:
  - `IDP_SCOPE=kwu.ac.kr`
  - `IDP_HOST_NAME=idp.kwu.ac.kr`
  - `JAVA_VERSION` 및 `JETTY_BASE_VERSION`은 VERSIONS 파일에서 자동 로드

### 3. 생성되는 이미지

- `registry.bitgaram.info/idp-kwu-ac-kr:YYYYMMDDHHMMSS` (타임스탬프 태그)
- `registry.bitgaram.info/idp-kwu-ac-kr:latest`

### 4. 로컬 빌드와 비교

로컬에서 `./build-idp-kwu-ac-kr` 스크립트를 실행하는 것과 동일한 Docker 빌드 명령어를 사용합니다:

```bash
docker build \
    --build-arg JAVA_VERSION=$JAVA_VERSION \
    --build-arg JETTY_BASE_VERSION=$JETTY_BASE_VERSION \
    --build-arg IDP_SCOPE=kwu.ac.kr \
    --build-arg IDP_HOST_NAME=idp.kwu.ac.kr \
    -t registry.bitgaram.info/idp-kwu-ac-kr:TIMESTAMP .
```

## 주의사항

- Shibboleth IdP가 설치되지 않은 경우 자동으로 `./install` 스크립트를 실행합니다
- 빌드 실패 시 GitHub Actions 로그를 확인하여 문제를 파악할 수 있습니다
- 레지스트리 인증 정보가 올바르게 설정되어야 푸시가 성공합니다
