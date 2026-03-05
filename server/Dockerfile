FROM node:20-alpine

RUN apk add --no-cache bash curl helm kubectl

WORKDIR /app
RUN npm init -y && npm pkg set type="module" && npm install express

COPY server/server.js .
COPY . /charts/universal-app

EXPOSE 3000
CMD ["node", "server.js"]