#
# Shibboleth Identity Provider for Kubernetes
#
# 기존 Dockerfile과 유사하지만 Shibboleth IdP 설정을 이미지에 포함
#

ARG JAVA_VERSION=amazoncorretto:17
FROM ${JAVA_VERSION}

# 필요한 패키지 설치 (tar 포함)
RUN yum install -y tar gzip wget

LABEL org.opencontainers.image.authors="RYU. G.S. <narzis@gmail.com>"
LABEL org.opencontainers.image.description="Shibboleth IdP for Kubernetes"

# Jetty 설정
ENV JETTY_HOME=/opt/jetty
ENV JETTY_BASE=/opt/jetty-base
ENV JETTY_LOGS=${JETTY_BASE}/logs
ENV IDP_HOME=/opt/shibboleth-idp

# Shibboleth 설치 관련 환경 변수 설정
ENV DIST=/opt/shibboleth-dist
ENV SEALPASS=changeit
ENV TFPASS=changeit

# Build arguments (must be provided via --build-arg)
ARG IDP_SCOPE
ARG IDP_SCOPE_DOMAIN  
ARG IDP_HOST_NAME
ARG IDP_ENTITYID
ARG IDP_ORG_DISPLAYNAME
ARG IDP_ORG_HOMEPAGE
ARG IDP_FORGOT_PASSWORD_URL
ARG IDP_SUPPORT_URL
ARG JETTY_BASE_VERSION=12.0

# Debug: Show ARG values immediately after declaration
RUN echo "=== ARG Values Debug ===" && \
    echo "IDP_SCOPE ARG: ${IDP_SCOPE}" && \
    echo "IDP_HOST_NAME ARG: ${IDP_HOST_NAME}" && \
    echo "IDP_ENTITYID ARG: ${IDP_ENTITYID}" && \
    echo "JETTY_BASE_VERSION ARG: ${JETTY_BASE_VERSION}" && \
    echo "========================"

# Immediately convert ARGs to ENVs to preserve values
ENV IDP_SCOPE=${IDP_SCOPE}
ENV IDP_SCOPE_DOMAIN=${IDP_SCOPE_DOMAIN}
ENV IDP_HOST_NAME=${IDP_HOST_NAME}
ENV IDP_ENTITYID=${IDP_ENTITYID}
ENV IDP_ORG_DISPLAYNAME=${IDP_ORG_DISPLAYNAME}
ENV IDP_ORG_HOMEPAGE=${IDP_ORG_HOMEPAGE}
ENV IDP_FORGOT_PASSWORD_URL=${IDP_FORGOT_PASSWORD_URL}
ENV IDP_SUPPORT_URL=${IDP_SUPPORT_URL}

# Jetty 로그 디렉토리는 볼륨으로 유지 
VOLUME ["${JETTY_LOGS}"]

# Jetty base 추가
ADD jetty-base-${JETTY_BASE_VERSION} ${JETTY_BASE}

# Jetty 배포판 추가
ADD jetty-dist/dist ${JETTY_HOME}

# 중요: Shibboleth IdP 디렉토리 복사 (볼륨으로 선언하지 않음)


# Shibboleth 배포판 복사 (설치 스크립트 포함)
COPY fetched/shibboleth-dist/ ${DIST}/


# REST 인증 JAR 파일 복사 및 배치
#COPY overlay/shibboleth-idp-custom/edit-webapp/WEB-INF/lib/shib-idp-rest-auth-5.1.4-jar-with-dependencies.jar ${IDP_HOME}/edit-webapp/WEB-INF/lib/ 


WORKDIR ${JETTY_BASE}

# ENV 값을 사용 (이미 위에서 ARG를 ENV로 변환했음)
RUN echo "=== Environment Variables ===" && \
    echo "IDP_SCOPE: ${IDP_SCOPE}" && \
    echo "IDP_HOST_NAME: ${IDP_HOST_NAME}" && \
    echo "IDP_ENTITYID: ${IDP_ENTITYID}" && \
    echo "SEALPASS: ${SEALPASS}" && \
    echo "TFPASS: ${TFPASS}" && \
    echo "========================" && \
    ${DIST}/bin/install.sh \
    -Didp.initial.modules=idp.intercept.Consent \
    --targetDir ${IDP_HOME} \
    --scope "${IDP_SCOPE}" \
    --entityID "${IDP_ENTITYID}" \
    --hostName "${IDP_HOST_NAME}" \
    --sealerPassword "${SEALPASS}" \
    --keystorePassword "${TFPASS}" \
    --noPrompt 
    # && mkdir -p ${IDP_HOME}/dist/webapp/WEB-INF/lib/ \
    # && cp ${IDP_HOME}/edit-webapp/WEB-INF/lib/shib-idp-rest-auth-5.1.4-jar-with-dependencies.jar ${IDP_HOME}/dist/webapp/WEB-INF/lib/

RUN echo "idp.session.StorageService = shibboleth.DatabaseStorageService" >> ${IDP_HOME}/conf/idp.properties && \
    echo "idp.consent.StorageService = shibboleth.DatabaseStorageService" >> ${IDP_HOME}/conf/idp.properties && \
    echo "idp.replayCache.StorageService = shibboleth.DatabaseStorageService" >> ${IDP_HOME}/conf/idp.properties && \
    echo "idp.artifact.StorageService = shibboleth.DatabaseStorageService" >> ${IDP_HOME}/conf/idp.properties && \
    echo "# Consent Configuration" >> ${IDP_HOME}/conf/idp.properties && \
    echo "idp.consent.attribute-release.enabled = true" >> ${IDP_HOME}/conf/idp.properties && \
    echo "idp.consent.attribute-release.compareValues = true" >> ${IDP_HOME}/conf/idp.properties

COPY overlay/shibboleth-idp-custom/ ${IDP_HOME}/

# Copy forwarded proxy configuration for reverse proxy support
COPY forwarded.ini ${JETTY_BASE}/start.d/

# Configure Jetty to bind to all interfaces (required for reverse proxy)
RUN sed -i 's/jetty.http.host=127.0.0.1/jetty.http.host=0.0.0.0/' ${JETTY_BASE}/start.d/idp.ini

RUN sed -i "s#__IDP_SCOPE__#${IDP_SCOPE}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_SCOPE_DOMAIN__#${IDP_SCOPE_DOMAIN}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_HOST_NAME__#${IDP_HOST_NAME}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_ORG_HOMEPAGE__#${IDP_ORG_HOMEPAGE}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_ORG_DISPLAYNAME__#${IDP_ORG_DISPLAYNAME}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_FORGOT_PASSWORD_URL__#${IDP_FORGOT_PASSWORD_URL}#" $IDP_HOME/messages/messages_ko.properties
RUN sed -i "s#__IDP_SUPPORT_URL__#${IDP_SUPPORT_URL}#" $IDP_HOME/messages/messages_ko.properties

# Install all plugins first, then build once
# JDBC StorageService 플러그인 설치
RUN cd /tmp && \
    curl -s -L https://shibboleth.net/downloads/identity-provider/plugins/jdbc/2.1.0/java-plugin-jdbc-storage-2.1.0.tar.gz -o jdbc-plugin.tar.gz && \
    mkdir -p jdbc-extract && \
    tar -xf jdbc-plugin.tar.gz -C jdbc-extract && \
    cd jdbc-extract && \
    find . -type f -name "*.jar" -exec cp {} ${IDP_HOME}/edit-webapp/WEB-INF/lib/ \; && \
    find . -path "*/conf/*" -type f -exec cp {} ${IDP_HOME}/conf/ \; && \
    cd /tmp && \
    rm -rf jdbc-extract jdbc-plugin.tar.gz

# Nashorn 플러그인 설치
RUN cd /tmp && \
    curl -s -L https://shibboleth.net/downloads/identity-provider/plugins/scripting/2.0.0/idp-plugin-nashorn-jdk-dist-2.0.0.tar.gz -o nashorn-plugin.tar.gz && \
    mkdir -p nashorn-extract && \
    tar -xf nashorn-plugin.tar.gz -C nashorn-extract && \
    cd nashorn-extract && \
    find . -type f -name "*.jar" -exec cp {} ${IDP_HOME}/edit-webapp/WEB-INF/lib/ \; && \
    find . -path "*/flows/*" -type d -exec cp -r {} ${IDP_HOME}/flows/ \; && \
    find . -path "*/conf/*" -type f -exec cp {} ${IDP_HOME}/conf/ \; && \
    cd /tmp && \
    rm -rf nashorn-extract nashorn-plugin.tar.gz

RUN cd ${IDP_HOME} && ./bin/module.sh -e idp.intercept.Consent
# Build IdP WAR with all plugins installed
RUN cd ${IDP_HOME} && ./bin/build.sh

# Jetty 로깅 모듈 활성화
CMD ["java",\
    "-Djdk.tls.ephemeralDHKeySize=2048", \
    "-Didp.home=/opt/shibboleth-idp", \
    "-Djetty.base=/opt/jetty-base",\
    "-Djetty.logs=/opt/jetty-base/logs",\
    "-jar", "/opt/jetty/start.jar"]

# 오버레이 추가
ADD overlay/jetty-base-${JETTY_BASE_VERSION}.tar ${JETTY_BASE}
RUN chmod 640 /opt/shibboleth-idp/conf/idp.properties
RUN chmod 640 /opt/shibboleth-idp/credentials/idp-signing.key

# 포트 노출
EXPOSE 80 443 8443