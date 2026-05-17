FROM debian:bullseye-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
    perl \
    build-essential \
    pkg-config \
    libx11-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    librsvg2-dev \
    libpoppler-glib-dev \
    libgtk-3-dev \
    libfreetype6-dev \
    libvlc-dev \
    p7zip-full \
    tar \
    bzip2 \
    xz-utils \
    lzop \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GID}" --non-unique builder \
 && useradd --uid "${UID}" --gid "${GID}" --non-unique --create-home builder

USER builder
WORKDIR /workspace

ENTRYPOINT ["perl", "make.pl"]
CMD ["build"]
