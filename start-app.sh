#!/bin/bash

export RAILS_ENV=production
nohup rails s --port 5678 > /dev/null 2>&1 &
echo $! > pid.file
