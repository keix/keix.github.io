FROM nginx:mainline-alpine3.17-slim

RUN apk update && apk add vim
COPY . /usr/share/nginx/html
