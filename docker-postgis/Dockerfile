FROM crjore4prod001.azurecr.io/jore4-postgres:18.6 AS postgres

ENV TZ=Europe/Helsinki
ENV \
 TIPPECANOE_VERSION=1.36.0 \
 TIPPECANOE_SHA256=0e385d1244a0d836019f64039ea6a34463c3c2f49af35d02c3bf241aec41e71b

# Install postgis tools & gdal-bin from the Debian repository.
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgis gdal-bin \
 && rm -rf /var/lib/apt/lists/*

# Build and install tippecanoe from source.
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    zlib1g-dev \
 && curl -Lo tippecanoe.tar.gz "https://github.com/mapbox/tippecanoe/archive/refs/tags/${TIPPECANOE_VERSION}.tar.gz" \
 && echo "$TIPPECANOE_SHA256 *tippecanoe.tar.gz" | sha256sum -c - \
 && mkdir -p /usr/src/tippecanoe \
 && tar \
  --extract \
  --file tippecanoe.tar.gz \
  --directory /usr/src/tippecanoe \
  --strip-components 1 \
 && rm tippecanoe.tar.gz \
 && cd /usr/src/tippecanoe \
 && make -j $(nproc --all) \
 && make install \
 && cd / \
 && rm -rf /usr/src/tippecanoe \
 && apt-get purge -y --autoremove \
    build-essential \
    libsqlite3-dev \
    zlib1g-dev \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

# Set locales.

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
