#!/usr/bin/env bash

set -eu

ORIGIN_DIR="$(pwd)"
echo "current dir: ORIGIN_DIR"

VERSION="0.635"

cd ~/Downloads/
rm -rf luau ||:
git clone https://github.com/luau-lang/luau.git
cd luau
git checkout "$VERSION"

cd "$ORIGIN_DIR"
echo "current dir: $(pwd)"

rm -rf luau ||:

mkdir -pv luau
cp -rv ~/Downloads/luau/{Analysis,Config,Common}/ luau/

mkdir -pv luau/Ast
cp -rv ~/Downloads/luau/Ast/include luau/Ast/

mkdir -pv luau/CLI
cp -rv ~/Downloads/luau/CLI/*.h luau/CLI/
