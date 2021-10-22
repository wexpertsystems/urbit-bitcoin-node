#!/usr/bin/env bash

# edit hosts as non-root
echo "$@" >> /etc/hosts
