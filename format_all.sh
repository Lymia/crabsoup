#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure -p stylua -p rustup -p clang-tools

set -eu
cd "$(dirname $0)"

cargo fmt
stylua -v --indent-type Spaces crabsoup
clang-format -i crabsoup-mlua-analyze/bindings/*.cpp
