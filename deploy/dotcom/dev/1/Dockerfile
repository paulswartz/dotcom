FROM hexpm/elixir:1.16.1-erlang-26.2.2-debian-buster-20240130

RUN apt-get update && apt-get install -y curl git make build-essential inotify-tools
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs

WORKDIR /app

COPY mix.exs .
COPY mix.lock .
COPY package.json .
COPY assets/package.json ./assets/package.json

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mix deps.get
RUN npm --prefix assets install --package-lock-only --ignore-scripts --no-save --audit false --fund false --loglevel verbose
CMD elixir --sname dotcom1 --cookie foobarbaz -S mix phx.server
