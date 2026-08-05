#!/bin/sh

set -eu

# `wrangler dev --local` owns the D1 emulator. Initialise only an empty named
# volume; repeating seed-exercises.sql would erase users' locally persisted
# Vance state on every container recreation.
if [ ! -f /data/.initialized ]; then
  ./node_modules/.bin/wrangler d1 execute fitness-coach --local --persist-to /data --file=schema.sql
  ./node_modules/.bin/wrangler d1 execute fitness-coach --local --persist-to /data --file=seed-exercises.sql
  ./node_modules/.bin/wrangler d1 execute fitness-coach --local --persist-to /data --file=seed-names.sql
  touch /data/.initialized
fi

exec ./node_modules/.bin/wrangler dev --local --persist-to /data --ip "$BIND_HOST" --port "$PORT"
