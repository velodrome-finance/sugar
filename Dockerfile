FROM ghcr.io/apeworx/ape:latest-slim

USER root

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

# TODO: move this into an ENV or sort of...
RUN python -c 'import vvm; vvm.install_vyper("0.4.0", True)'
RUN ape pm install
RUN ape pm compile

ENTRYPOINT []
