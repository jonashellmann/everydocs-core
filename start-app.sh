#!/bin/bash

nohup rails s --port 5678 -e development > /dev/null 2>&1 &
echo $! > pid.file
