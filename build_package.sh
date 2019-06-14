#!/bin/bash

export MIX_ENV=prod

mix local.hex --force
mix do deps.get, compile, release --upgrade --env=prod, ecto.create
