# Building, Publishing & Installing the Middleware GPU Collector

Run all commands from this directory (`middleware-gpu-collector/`).

There are two ways to ship the collector:

- **Binary tarball** (`release.sh` → GitHub release → `install-middleware-gpu.sh`
  installs it as a systemd service). See [Binary tarball release](#binary-tarball-release).
- **Docker image** (`Dockerfile.root` → GHCR). See [Docker image](#docker-image).

---

# Binary tarball release

`release.sh` builds the `otelcol-middleware-gpu` binary for **linux/amd64 and
linux/arm64** with CGO + the `gpu` build tag (required by the dcgm/nvml
receivers), packages each as a `.tar.gz`, generates `SHA256SUMS`, and optionally
uploads everything to a GitHub release. The build runs inside Docker via
`Dockerfile.build`, so no Go toolchain or cross-compilers are needed on the host.

## Prerequisites

```bash
# buildx builder (one-time).
docker buildx create --name gpu-builder --use --bootstrap

# For building arm64 on an amd64 host, register QEMU emulation (one-time).
docker run --privileged --rm tonistiigi/binfmt --install all

# For --publish: authenticate the gh CLI (needs repo write access).
gh auth login
```

## Build the tarballs (no upload)

```bash
./release.sh --version 0.1.2
```

This produces, in `dist/`:

```
otelcol-middleware-gpu_0.1.2_linux_amd64.tar.gz
otelcol-middleware-gpu_0.1.2_linux_arm64.tar.gz
SHA256SUMS
```

## Build and publish to GitHub releases

```bash
./release.sh --version 0.1.2 --publish
```

Creates (or updates) release `v0.1.2` in
`middleware-labs/opentelemetry-operations-collector` and uploads the tarballs +
`SHA256SUMS`. Override the repo with `MW_GPU_GITHUB_REPO=owner/name`.

Options: `--version <x.y.z>` (required), `--publish`, `--dist <dir>` (default
`dist`). Run `./release.sh --help` for details.

## Installing on a host

Once a release is published, install on a GPU host with `install-middleware-gpu.sh`.
It downloads the matching tarball, verifies its checksum, installs the binary to
`/usr/bin`, writes the config + systemd unit, and starts the service (as root).

```bash
sudo MW_TARGET="https://<uid>.middleware.io:443" \
     MW_API_KEY="<your-api-key>" \
     bash install-middleware-gpu.sh

# Pin a version, or preview without installing:
sudo MW_TARGET=... MW_API_KEY=... MW_GPU_VERSION=0.1.2 bash install-middleware-gpu.sh
sudo bash install-middleware-gpu.sh --dry-run

# Uninstall:
sudo bash install-middleware-gpu.sh --uninstall
```

Run `bash install-middleware-gpu.sh --help` for all options. After install:

```bash
systemctl status otelcol-middleware-gpu
journalctl -u otelcol-middleware-gpu -f
```

---

# Docker image

This builds a multi-arch (linux/amd64 + linux/arm64) image from `Dockerfile.root`
and pushes it to GHCR. The collector runs as **root** in this image so the
dcgm/nvml receivers have unrestricted access to the NVIDIA driver/devices.

## Image reference

```
ghcr.io/middleware-labs/otelcol-middleware-gpu:<tag>
```

## One-time setup

```bash
# Create a buildx builder that supports multi-platform builds.
docker buildx create --name gpu-builder --use --bootstrap

# Log in to GHCR (token needs write:packages scope).
echo "$GH_TOKEN" | docker login ghcr.io -u <github-username> --password-stdin
```

## Multi-arch build & push

The build context is the repo root (`..`) because `Dockerfile.root` copies the
whole project to compile custom GPU components. `-f Dockerfile.root` selects the
hand-maintained, run-as-root Dockerfile.

```bash
IMAGE=ghcr.io/middleware-labs/otelcol-middleware-gpu
TAG=0.1.2

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.root \
  -t ${IMAGE}:${TAG} \
  -t ${IMAGE}:latest \
  --push \
  ..
```

- `--platform linux/amd64,linux/arm64` produces a single multi-arch manifest.
- `--push` builds and pushes in one step (multi-arch images cannot be loaded
  into the local Docker engine, so `--push` is required to publish them).
- The build cross-compiles arm64 from an amd64 host using
  `gcc-aarch64-linux-gnu` (installed inside `Dockerfile.root`).

### Build a single architecture locally (for testing)

To build just your host arch and load it into the local Docker engine:

```bash
docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile.root \
  -t ghcr.io/middleware-labs/otelcol-middleware-gpu:dev \
  --load \
  ..
```

## Verify the pushed manifest

```bash
docker buildx imagetools inspect ghcr.io/middleware-labs/otelcol-middleware-gpu:0.1.2
```

You should see both `linux/amd64` and `linux/arm64` entries.

## Running the image

The dcgm/nvml receivers need GPU access via the NVIDIA Container Toolkit
(`--gpus all`). The image already bakes in `config.example.yaml` at
`/etc/otelcol-middleware-gpu/config.yaml`, which reads two env vars:

```bash
docker run --rm --gpus all \
  -e MW_TARGET="https://<uid>.middleware.io:443" \
  -e MW_API_KEY="<your-api-key>" \
  ghcr.io/middleware-labs/otelcol-middleware-gpu:0.1.2
```

To run with a different config, mount your own over the baked-in path:

```bash
docker run --rm --gpus all \
  -e MW_TARGET="https://<uid>.middleware.io:443" \
  -e MW_API_KEY="<your-api-key>" \
  -v "$PWD/my-config.yaml:/etc/otelcol-middleware-gpu/config.yaml:ro" \
  ghcr.io/middleware-labs/otelcol-middleware-gpu:0.1.2
```

## Stopping / cleaning up the buildx builder

The `buildx create --bootstrap` step starts a long-running BuildKit container
(`buildx_buildkit_gpu-builder0`). When you're done building, stop and remove it.

```bash
# Stop the builder's BuildKit container (it can be restarted later).
docker buildx stop gpu-builder

# Remove the builder entirely (deletes its build cache).
docker buildx rm gpu-builder

# Switch back to the default builder.
docker buildx use default
```

To inspect or find builders/containers:

```bash
docker buildx ls                          # list builders and their state
docker ps --filter name=buildx_buildkit   # show the running BuildKit container
```
