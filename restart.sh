#!/bin/sh
kill -INT $(cat tmp/pids/server.pid)
script/rails server -d
tail -f log/development.log