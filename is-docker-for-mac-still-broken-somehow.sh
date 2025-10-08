#!/usr/bin/env bash

# A simple "test" that does something similar to
# https://bazel.build/install/docker-container
# but trying to build gRPC instead of Abseil.
# The build is expected to fail on MacOS, but succeed  on Linux,
# demonstrating the bug
# that motivated the auxiliary `bazel-output-sync` container.

set -e

cwd="$(pwd)"
tmpdir="$(mktemp -d)"
status=0

if docker run \
  --user=0 \
  --env=USER=0 \
  --volume="$cwd":"$cwd":ro \
  --volume="$tmpdir":"$tmpdir" \
  --workdir="$cwd" \
  gcr.io/bazel-public/bazel:latest \
  --output_user_root="$tmpdir" \
  build @grpc//:grpc
then
  # Hopefully this happens eventually.
  echo -e "\nHuh, I guess it's fixed!"
  status=1
else
  echo -e "\nYes, it is still broken!"
fi

rm -r "$tmpdir"
exit $status
