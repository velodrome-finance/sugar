FROM python:3.10-alpine

RUN apk add --no-cache \
  git npm build-base linux-headers python3-dev tk libc6-compat gcompat cargo

RUN npm install -g ganache

COPY . /app
WORKDIR /app

RUN pip install "cython<3.0.0" && pip install --no-build-isolation pyyaml==5.4.1
RUN pip install -r requirements.txt

RUN brownie networks add Bob bob-main host=https://rpc.gobob.xyz/ chainid=60808  
RUN brownie networks add Mode mode-main host=https://mainnet.mode.network chainid=34443
