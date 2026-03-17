FROM elixir:1.17-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
COPY config ./config

RUN mix deps.get --only prod

COPY lib ./lib

RUN mix deps.compile && mix release

EXPOSE 4100

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${LOCUS_HTTP_PORT:-4100}/health || exit 1

CMD ["_build/prod/rel/locus/bin/locus", "start"]
