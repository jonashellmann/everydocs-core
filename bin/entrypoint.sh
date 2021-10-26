#!/bin/bash
set -e

rake db:migrate

exec "$@"
