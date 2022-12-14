FROM python:3.10-alpine

RUN apk add --no-cache \
  git npm build-base linux-headers python3-dev tk libc6-compat gcompat

RUN npm install -g ganache

COPY . /app
WORKDIR /app

RUN pip install --no-cache-dir -r requirements.txt
