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
  --volume="$cwd":"$cwd":ro \
  --volume="$tmpdir":/home/ubuntu/output \
  --workdir="$cwd" \
  gcr.io/bazel-public/bazel:latest \
  --output_user_root=/home/ubuntu/output \
  build @grpc//:grpc
then
  # This occurs on Linux today.
  # Hopefully it happens on Mac eventually.
  echo -e "\nHuh, I guess it's fixed!"
  status=1
else
  echo -e "\nYes, it is still broken!"
fi

yes | rm -r "$tmpdir"
exit $status
