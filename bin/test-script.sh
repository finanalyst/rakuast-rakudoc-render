#!/bin/sh
#
# Test script.
#
# Meant to be invoked from within a clean container, so we
# can make sure we don't depend on any local state in CI.
#
# Example:
#
#     podman run -v $PWD:/src -w /src docker.io/rakudo-star:latest sh ./bin/test-script.sh
#
set -e
echo "Installing system dependencies."
apt-get update -y
apt-get install -y build-essential

echo "Installing Raku library dependencies."
zef install --deps-only .
zef install -/precompile-install .

# prove6 is pre-installed in the open source rakudo-star image
echo "Running tests with prove6."
prove6 xt/*

echo "Done."

