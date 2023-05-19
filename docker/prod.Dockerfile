# 도커를 실행하는 주요 이점은 다음과 같습니다:

# 일관성: 도커는 컨테이너를 사용하여 애플리케이션과 그 종속성을 패키징합니다. 이렇게 패키징
# 격리: 도커는 컨테이너를 사용하여 애플리케이션을 격리된 환경에서 실행합니다. 이를 통해 애플리케이션 간의 충돌이나 영향을 최소화하고, 보안을 강화할 수 있습니다.
# 확장성: 도커는 컨테이너를 쉽게 확장할 수 있도록 지원합니다. 컨테이너는 가볍고 빠르게 생성 및 제거할 수 있으며, 필요에 따라 수평적으로 스케일 아웃할 수 있습니다.
# 이식성: 도커는 애플리케이션을 독립적인 컨테이너로 패키징하므로, 다양한 환경에서 실행할 수 있습니다. 개발 환경과 프로덕션 환경을 일치시키는 데 도움이 되며, 클라우드 환경에서의 배포 및 관리를 용이하게 합니다.

# 이러한 이점을 통해 도커는 애플리케이션 개발, 테스트, 배포를 간편하고 효율적으로 수행할 수 있게 해줍니다.

FROM node:20-alpine AS base

# 필요할 때만 종속 항목 설치(도커 이미지 사이즈를 줄이기 위한 작업)
FROM base AS deps
# libc6-compat이 필요한 이유를 이해하려면 https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine을 확인하세요.
RUN apk add --no-cache libc6-compat

WORKDIR /test-docker-ncloud

COPY package.json ./

# RUN npm install
RUN npm install --production
# --production 플래그를 추가하여 개발에 필요한 종속성을 설치하지 않고, 프로덕션에 필요한 종속성만 설치합니다. 이렇게 하면 불필요한 종속성이 제거되어 이미지 크기를 줄일 수 있습니다.


# 필요할 때만 소스 코드를 다시 빌드합니다.
FROM base AS builder
WORKDIR /test-docker-ncloud

# 이전 단계에서 빌드된 다른 도커 이미지에서 /test-docker-ncloud/node_modules 경로의 종속성을 현재 이미지의 ./node_modules 경로로 복사한다
# >> FROM base AS builder 를 하고 COPY —from=deps를 하는것은 위에서 빌드 이미지를 줄이기 위한 작업이라고 했습니다. 이렇게 빌드된 녀석들만 가져와서 사용하도록 해서 깔끔(?)한 상태를 만드는 것입니다.<< 
COPY --from=deps /test-docker-ncloud/node_modules ./node_modules

# 필요한 모든 파일을 복사
COPY . .

# 이것은 트릭을 수행하고 각 환경에 해당하는 env 파일을 사용합니다.
COPY .env.development .env.production

RUN npm run build

FROM base AS runner
WORKDIR /test-docker-ncloud

# NODE_ENV를 production으로 환경 변수 설정
ENV NODE_ENV production

# 도커 이미지 내에서 그룹과 사용자를 생성
# 도커 이미지 내에서 실행되는 애플리케이션을 특정 그룹 및 사용자의 권한으로 실행하고자 할 때 사용. 보안 및 권한 관리 측면에서 유용
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# builder 된 곳에서 만들어진 /test-docker-ncloud/public을 해당 runner 이미지에 추가해주기 위해 복사
COPY --from=builder /test-docker-ncloud/public ./public

# 출력 추적을 자동으로 활용하여 이미지 크기 줄이기
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /test-docker-ncloud/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /test-docker-ncloud/.next/static ./.next/static

USER nextjs

# 3000 포트 사용 및 포트 3000 환경변수 설정
EXPOSE 3000
ENV PORT 3000

# 최종 실행. 위에 standalone로 만들어졌다면 server.js로 실행
CMD ["node", "server.js"]