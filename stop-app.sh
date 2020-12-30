#!/bin/bash

pid=$(sudo lsof -t -i:5678)
sudo kill -9 $pid
