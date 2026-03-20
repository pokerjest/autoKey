#!/bin/zsh
cd /Users/pokerjest/github/autoKey

set -e

if [ ! -f AutoKeyWriter ] || [ AutoKeyWriter.m -nt AutoKeyWriter ]; then
  clang -fobjc-arc -framework Cocoa AutoKeyWriter.m -o AutoKeyWriter
fi

./AutoKeyWriter
