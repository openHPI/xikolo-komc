# syntax = docker/dockerfile:1.12-labs@sha256:c0232100a2ae4603c5c6a8a97b77d002bbf994a69f19f70d7b487e1cd7fa5612

#
# Assets build environment (with NodeJS)
#
# * Compile and bundle web assets
#
FROM timbru31/ruby-node:3.3-slim-20@sha256:b0ac83410d2bca5ade302e880a129d75d1e484e8d9b42c2edba510ac09d75839 AS assets

ARG BRAND=xikolo
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV BRAND=${BRAND}
ENV MALLOC_ARENA_MAX=2
ENV RAILS_ENV=production
ENV CPPFLAGS="-DPNG_ARM_NEON_OPT=0"

RUN mkdir --parents /app/
WORKDIR /app/

# Install dependencies for installing gems
RUN <<EOF
  apt-get --yes --quiet update
  apt-get --yes --quiet install \
    autoconf \
    build-essential \
    git \
    libcurl4 \
    libffi-dev \
    libidn11-dev \
    libpq-dev \
    libsodium23 \
    libtool \
    pax-utils \
    pkg-config \
    shared-mime-info \
    tzdata
EOF

COPY ./clients /app/clients
COPY ./gems /app/gems
COPY Gemfile Gemfile.lock /app/

RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local without 'development test integration'
  bundle install --jobs 4 --retry 3
EOF

COPY package.json yarn.lock .yarnrc.yml /app/

RUN <<EOF
  corepack yarn install
EOF

COPY --exclude=docker/rootfs --exclude=services . /app/

RUN <<EOF
  make --jobs="$(./docker/tool/njobs)" all
EOF

#
# Application build environment
#
# * Install gems
# * Collect required native dependencies for gems
# * Clean up application directory
#
FROM ruby:3.3.6-slim@sha256:694f3ccb7edc9b39a455040a070f4140d4778692dd739c9359045de20ae82705 AS build

ARG BRAND=xikolo
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV BRAND=${BRAND}
ENV MALLOC_ARENA_MAX=2
ENV RAILS_ENV=production

RUN mkdir --parents /app/
WORKDIR /app/

# Install dependencies for installing gems
RUN <<EOF
  apt-get --yes --quiet update
  apt-get --yes --quiet install \
    build-essential \
    git \
    libcurl4 \
    libffi-dev \
    libidn11-dev \
    libpq-dev \
    libsodium23 \
    pax-utils \
    shared-mime-info \
    tzdata
EOF

COPY ./clients /app/clients
COPY ./gems /app/gems
COPY Gemfile Gemfile.lock /app/

RUN <<EOF
  gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
  bundle config set --local without 'development test integration'
  bundle install --jobs 4 --retry 3
EOF

# Scan gem files for linked native libaries, lookup the packages they
# are shipped with, and colled it list into a file so that only required
# packages can be installed in the runtime image below.
RUN <<EOF
  scanelf --recursive --needed --nobanner --format '%n#p' /usr/local/bundle/ \
    | tr ',' '\n' \
    | sort -u \
    | grep -v libruby.so* \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | tee /usr/local/bundle/packages
EOF

# Copy rest of the application (see .dockerignore too)
COPY . /app/
COPY --from=assets /app/public/assets/ /app/public/assets/

# Cleanup application directory
RUN <<EOF
  rm -rf /app/config/assets
  rm -rf /app/docker
  rm -rf /app/node_modules
  rm -rf /app/services
  rm -rf /app/tmp
EOF

#
# Runtime image
#
FROM docker.io/ruby:3.3.6-slim@sha256:694f3ccb7edc9b39a455040a070f4140d4778692dd739c9359045de20ae82705

ARG BRAND=xikolo
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV BRAND=${BRAND}
ENV MALLOC_ARENA_MAX=2
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

RUN mkdir --parents /app/
WORKDIR /app/

# Add system user for running the app
RUN useradd --create-home --shell /bin/bash xikolo

# Install extra dependencies for runtime environment
RUN <<EOF
  apt-get --yes --quiet update
  apt-get --yes --quiet --no-install-recommends install \
    curl \
    ffmpeg \
    git \
    libcurl4 \
    libsodium23 \
    nginx \
    shared-mime-info \
    tzdata \
    xz-utils
EOF

COPY docker/rootfs/web/ /
COPY docker/bin/ /docker/bin
RUN /docker/bin/install-s6-overlay

# Copy installed gems and config from `build` stage above
COPY --from=build /usr/local/bundle /usr/local/bundle

# Install required runtime packages for native dependencies
RUN <<EOF
  xargs apt-get install --yes < /usr/local/bundle/packages
EOF

# Copy application files from build stage
COPY --from=build /app/ /app/

EXPOSE 80/tcp

CMD [ "server" ]
ENTRYPOINT [ "/init", "with-contenv", "/app/bin/entrypoint" ]