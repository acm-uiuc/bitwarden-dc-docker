#!/bin/sh
# Records every invocation for assertion in tests
echo "$*" >> /tmp/bwdc_calls
case "$1" in
    --version) echo "bwdc-mock 0.0.0"; exit 0 ;;
    login)     exit 0 ;;
    sync)      exit 0 ;;
    config)    exit 0 ;;
    *)         exit 0 ;;
esac
