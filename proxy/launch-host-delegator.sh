#!/usr/bin/env bash

nohup python3 host_delegate_serv.py \
  --host 127.0.0.1 \
  --port 28789 \
  &>/dev/null &