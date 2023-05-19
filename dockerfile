# 사용할 Node.js 버전을 선택합니다.
FROM node:14

# 작업 디렉토리를 설정합니다.
WORKDIR /test-docker-ncloud

# 애플리케이션 종속성을 설치합니다.
COPY package*.json ./
RUN npm install

# 소스 코드를 복사합니다.
COPY . .

# 애플리케이션을 빌드합니다.
RUN npm run build

# 애플리케이션을 실행합니다.
CMD ["npm", "start"]