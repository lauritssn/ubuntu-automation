#!/bin/bash
# Automatic logout for idle sessions (30 minutes)
# Ubuntu 24.04 compatible session timeout configuration
TMOUT=1800
readonly TMOUT
export TMOUT

# Make the timeout apply to all shells
case $- in
    *i*) ;;
    *) return ;;
esac