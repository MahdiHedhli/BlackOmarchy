#!/bin/sh
VERSION=20251011
verify_keyring()
{
  gpg --keyserver keyserver.ubuntu.com \
     --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1
}
#verify_keyring
