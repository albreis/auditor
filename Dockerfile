FROM ubuntu:22.04

LABEL org.opencontainers.image.source=https://github.com/albreis/auditor

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    inotify-tools \
    git \
    curl \
    diffutils \
    coreutils \
    bash \
    python3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /watch

COPY watch.sh /usr/local/bin/watch.sh
RUN chmod +x /usr/local/bin/watch.sh

CMD ["/usr/local/bin/watch.sh"]
