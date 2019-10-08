#!/bin/bash

pid=$(cat pid.file)
sudo kill $pid
