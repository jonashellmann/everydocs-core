#!/bin/bash

export RAILS_ENV=production

#export SECRET_KEY_BASE=""
#export EVERYDOCS_DB_ADAPTER=mysql2
#export EVERYDOCS_DB_NAME=everydocs
#export EVERYDOCS_DB_USER=everydocs
#export EVERYDOCS_DB_PASSWORD=""
#export EVERYDOCS_DB_HOST=localhost
#export EVERYDOCS_DB_PORT=3306

nohup rails s --port 5678 > /dev/null 2>&1 &
