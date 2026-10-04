FROM docker.io/library/node:22-bookworm-slim AS web
WORKDIR /opt/tao-of-lila/web/yarrow-casting
COPY web/yarrow-casting/package*.json ./
RUN npm ci
COPY web/yarrow-casting/src ./src
RUN npm run build && npm run build:journey

# Regenerate the shared catalogue from canonical seeds for every deployment.
WORKDIR /opt/tao-of-lila
COPY scripts/build-state-catalog.mjs ./scripts/build-state-catalog.mjs
COPY data/leela.json data/state-view-metadata.json ./data/
COPY app/public/journey/hexagram-labels.json ./app/public/journey/hexagram-labels.json
RUN node scripts/build-state-catalog.mjs

FROM docker.io/library/haskell:9.10.3-slim-bookworm AS build

RUN apt-get update \
  && apt-get install -y --no-install-recommends libpq-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/tao-of-lila
COPY tao-of-lila.cabal ./
COPY cabal.project.container ./cabal.project
RUN cabal update && cabal build all --only-dependencies -j2

COPY src ./src
COPY app/Main.hs ./app/Main.hs
RUN cabal build exe:tao-of-lila-api -j2
RUN mkdir -p /opt/dist && cp "$(cabal list-bin exe:tao-of-lila-api)" /opt/dist/tao-of-lila-api

FROM docker.io/library/debian:bookworm-slim

WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libgmp10 libpq5 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/dist/tao-of-lila-api /usr/local/bin/tao-of-lila-api
COPY data ./data
COPY app/public ./app/public
COPY --from=web /opt/tao-of-lila/data/state-views.json ./data/state-views.json
COPY --from=web /opt/tao-of-lila/app/public/journey/state-views.json ./app/public/journey/state-views.json
COPY --from=web /opt/tao-of-lila/app/public/yarrow/casting.js ./app/public/yarrow/casting.js
COPY --from=web /opt/tao-of-lila/app/public/journey/ceremony.js ./app/public/journey/ceremony.js

ENV PORT=8080
EXPOSE 8080

CMD ["tao-of-lila-api"]
