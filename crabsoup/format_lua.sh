#! /usr/bin/env nix-shell
#! nix-shell -i bash --pure -p stylua

set -eu
cd "$(dirname $0)"
stylua -v --indent-type Spaces .
