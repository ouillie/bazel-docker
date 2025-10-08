# `bazel-docker`

A drop-in replacement for `bazel` that runs commands in a persistent Docker container.

## Background

There is an official [Bazel Docker image],
which is basically just Ubuntu with Bazel pre-installed;
a nice, canonical, Linux-based build environment.

[Bazel recommends] using it with `docker run`
by bind-mounting your workspace and build output directories into the container;
an elegant, simple solution
&mdash; with a couple major drawbacks:

1. You have to rebuild the analysis cache every time you run a command.
   This significantly degrades rapid iteration.
2. When you bind-mount a MacOS directory to the container's build output directory directly,
   you can experience mysterious build failures that seem to be caused by latency issues.
   See [Output Synchronization](#output-synchronization).

This script is a mitigation of both issues.

[Bazel Docker image]: https://console.cloud.google.com/artifacts/docker/bazel-public/us/gcr.io/bazel
[Bazel recommends]: https://bazel.build/install/docker-container

## Usage

It's just an API-compatible drop-in replacement for the bazel command:

```bash
bazel-docker build @repo//package/...
bazel-docker test --nocache_test_results //some:thing
bazel-docker run //...  # etc.
```

Basically, the script will:

1. Generate a unique name based on the path to the root of the current workspace.
2. Check to see if a container with that name is already running.
   - If not, start a new instance of the official Bazel container with that name.
3. Execute the Bazel command in that container
   (with `docker exec` instead of `docker run`).

After the initial startup, the container,
and the running Bazel server that holds the analysis cache in memory,
will persist until manually shut down,
just like a normal Bazel server running directly on the host.

The container is configured such that
all absolute and relative paths printed to the terminal
are valid and accessible on the host system as-is
shortly after a command finishes.

The script also handles relative targets,
so you can run e.g. `bazel-docker build :target` from a subpackage directory,
and it will work that same as a normal invocation of `bazel`.

It also bind-mounts `${HOME}/.ssh` into the container (read-only)
so that [`git_override`] works the same as it would on the host.

[`git_override`]: https://bazel.build/rules/lib/globals/module#git_override

### Getting the build container name.

You can get the unique name of the build container
associated with the current working directory
(which can be useful for tooling purposes)
with:

```bash
bazel-docker --name
```

This is the only API difference between the `bazel-docker` script and `bazel` itself.

## Output Synchronization

Bazel can have issues
when the container's output directory is bind-mounted directly to a MacOS directory
using either the VirtioFS or gRPC FUSE filesharing systems.
To get around this, the output directory of every build container
is instead bind-mounted to a single, shared, named volume.
Each container naturally only accesses a dedicated subdirectory of that volume
because of how Bazel works.

That volume is also bind-mounted into a single auxiliary container called `bazel-output-sync`,
whose only purpose is to synchronize the files from the volume
to a bind-mounted host directory using [Unison].
Introducing this layer of indirection solves the build issues,
at the cost of ~2x disk bandwidth usage
and a negligible amount of latency (perhaps a second or two)
before build outputs actually become available on the host.

[Unison]: https://en.wikipedia.org/wiki/Unison_(software)
