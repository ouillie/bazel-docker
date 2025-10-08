# `bazel-docker`

A drop-in replacement for `bazel` that runs commands in a *persistent* Docker container.

Implemented as a standalone ~150-line Bash script.

> [!WARNING]
> Don't use this if there is a user account on your system named `_docker`
> that runs Bazel commands.
> There must be somebody&hellip;

## Background

There is an official [Bazel Docker image],
which is basically just Ubuntu with Bazel pre-installed;
a nice, canonical, Linux-based build environment.

[Bazel recommends] using it with `docker run`
by bind-mounting your workspace and build output directories into the container;
an elegant, simple solution
&mdash; with a couple major drawbacks:

1. You have to restart the Bazel server and rebuild the analysis cache
   every time you run a command.
   This significantly slows iteration speed.
2. When you bind-mount a MacOS directory to the container's build output directory directly,
   you can experience mysterious build failures
   that seem to be caused by latency issues in Docker's filesharing system.
   See [Output Synchronization](#output-synchronization).

This script is a mitigation of both issues.

[Bazel Docker image]: https://console.cloud.google.com/artifacts/docker/bazel-public/us/gcr.io/bazel
[Bazel recommends]: https://bazel.build/install/docker-container

## Usage

It's an API-compatible drop-in replacement for `bazel`:

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

After the initial startup, the container
(and the running Bazel server that holds the analysis cache in memory)
will persist until manually shut down,
just like a normal Bazel server running directly on the host.

Any file path within the workspace or the build output roots
will be the same on the container as it is on the host.
In other words, build errors will always have accurate file paths.

The script also handles relative targets,
so you can run e.g. `bazel-docker build :target` from a subpackage directory,
and it will be like running `bazel build :target`.

It also bind-mounts `${HOME}/.ssh` into the container (read-only)
so that [`git_override`] works the same as it would on the host.

[`git_override`]: https://bazel.build/rules/lib/globals/module#git_override

#### Getting the build container name.

You can get the unique name of the build container
associated with the current working directory
(which can be useful for tooling purposes)
with:

```bash
bazel-docker --name
```

This is the only API difference between the `bazel-docker` script and `bazel` itself.

## Installation

Requirements:

- Docker
- Bazel
- Bash

It's a standalone, portable Bash script.
You could just do this:

```bash
sudo curl --location --fail --silent --show-error \
  --output=/usr/local/bin/bazel-docker \
  'https://raw.githubusercontent.com/ouillie/bazel-docker/refs/heads/main/bazel-docker' \
  && sudo chmod +x /usr/local/bin/bazel-docker
```

You certainly don't have to, but feel free to read it first!
It's short and well-commented,
and there is a lot of room to customize various things,
like whether you want to inherit any environment variables
from the host system,
or add any other docker flags.

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
at the cost of ~2x disk usage
and a negligible amount of latency (perhaps a second or two)
before build outputs actually become available on the host.

Try running [`./is-docker-for-mac-still-broken-somehow.sh`]
on both Mac and Linux.
See how the build fails on Mac, but succeeds on Linux.
Props to whoever can explain why.

[Unison]: https://en.wikipedia.org/wiki/Unison_(software)
[`./is-docker-for-mac-still-broken-somehow.sh`]: is-docker-for-mac-still-broken-somehow.sh
