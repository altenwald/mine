#!/bin/bash

mix local.hex --force
MIX_ENV=prod mix release
