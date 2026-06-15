#!/bin/bash
# Middleware GPU Collector - Build & Release Script
#
# Builds the otelcol-middleware-gpu binary for linux/amd64 and linux/arm64 with
# CGO + the "gpu" build tag (required by the dcgm/nvml receivers), packages each
# as a .tar.gz containing just the binary, generates SHA256SUMS, and (optionally)
# uploads everything to a GitHub release.
#
# Builds happen INSIDE Docker via Dockerfile.build so the arm64 cross-compile
# toolchain (gcc-aarch64-linux-gnu) and CGO are handled exactly like the image
# build. No Go toolchain or cross-compilers are needed on the host.
#
# Run from the middleware-gpu-collector/ directory.
#
# Usage:
#   ./release.sh --version 0.1.2                 # build + package only
#   ./release.sh --version 0.1.2 --publish       # build, package, upload to GH release
#
# Requirements: docker (with buildx), tar, sha256sum; gh CLI for --publish.

set -euo pipefail

readonly BINARY_NAME="otelcol-middleware-gpu"
readonly GITHUB_REPO="${MW_GPU_GITHUB_REPO:-middleware-labs/opentelemetry-operations-collector}"
# Architectures to build. Naming matches the install script's expectation:
#   otelcol-middleware-gpu_<version>_linux_<arch>.tar.gz
readonly ARCHES=("amd64" "arm64")

VERSION=""
PUBLISH=false
DIST_DIR="dist"

log_info()  { echo "[INFO]  $*"; }
log_ok()    { echo "[OK]    $*"; }
log_error() { echo "[ERROR] $*"; }

usage() {
    cat <<EOF
Build & release the Middleware GPU collector tarballs (linux amd64 + arm64).

USAGE:
    ./release.sh --version <x.y.z> [--publish] [--dist <dir>]

OPTIONS:
    --version <x.y.z>   Release version (required). Used in the tag (v<x.y.z>) and tarball names.
    --publish           Create/upload a GitHub release v<version> with the tarballs + SHA256SUMS.
    --dist <dir>        Output directory for artifacts (default: dist).
    --help              Show this help.

ENVIRONMENT:
    MW_GPU_GITHUB_REPO  Override the GitHub repo (owner/name). Default: ${GITHUB_REPO}
EOF
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="${2:-}"; shift 2 ;;
        --publish) PUBLISH=true; shift ;;
        --dist)    DIST_DIR="${2:-}"; shift 2 ;;
        --help|-h) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

VERSION="${VERSION#v}"
if [ -z "$VERSION" ]; then
    log_error "--version is required (e.g. --version 0.1.2)."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    log_error "docker is required."
    exit 1
fi
if [ "$PUBLISH" = true ] && ! command -v gh >/dev/null 2>&1; then
    log_error "gh CLI is required for --publish. Install it or drop --publish."
    exit 1
fi

# Project root is one level up (Dockerfile.build copies the whole project).
PROJECT_ROOT="$(cd .. && pwd)"
mkdir -p "$DIST_DIR"
DIST_ABS="$(cd "$DIST_DIR" && pwd)"

# ─── Build + package each arch ────────────────────────────────────────────────
# We build the runtime image per-arch with buildx, then create a container and
# copy the compiled binary out of it. Dockerfile.build compiles with CGO and the
# gpu tag (and cross-compiles for arm64 via gcc-aarch64-linux-gnu).

build_arch() {
    local arch="$1"
    local image_tag="${BINARY_NAME}-build:${VERSION}-${arch}"
    local tarball="${BINARY_NAME}_${VERSION}_linux_${arch}.tar.gz"
    local stage_dir
    stage_dir="$(mktemp -d -t mw-gpu-rel-XXXXXX)"

    log_info "Building ${arch} image (CGO + gpu tag) via Dockerfile.build..."
    docker buildx build \
        --platform "linux/${arch}" \
        -f Dockerfile.build \
        -t "$image_tag" \
        --load \
        "$PROJECT_ROOT"

    log_info "Extracting binary from ${arch} image..."
    local cid
    cid="$(docker create --platform "linux/${arch}" "$image_tag")"
    # The binary lives at / in the runtime image (see Dockerfile.build COPY).
    docker cp "${cid}:/${BINARY_NAME}" "${stage_dir}/${BINARY_NAME}"
    docker rm -f "$cid" >/dev/null

    chmod 755 "${stage_dir}/${BINARY_NAME}"

    log_info "Packaging ${tarball}..."
    tar -czf "${DIST_ABS}/${tarball}" -C "$stage_dir" "$BINARY_NAME"
    rm -rf "$stage_dir"
    log_ok "Created ${DIST_DIR}/${tarball}"
}

for arch in "${ARCHES[@]}"; do
    build_arch "$arch"
done

# ─── Checksums ────────────────────────────────────────────────────────────────

log_info "Generating SHA256SUMS..."
(
    cd "$DIST_ABS"
    sha256sum "${BINARY_NAME}"_*.tar.gz > SHA256SUMS
)
log_ok "Wrote ${DIST_DIR}/SHA256SUMS"

# ─── Publish ──────────────────────────────────────────────────────────────────

if [ "$PUBLISH" = true ]; then
    RELEASE_TAG="v${VERSION}"
    log_info "Publishing GitHub release ${RELEASE_TAG} to ${GITHUB_REPO}..."
    if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
        log_info "Release ${RELEASE_TAG} exists; uploading/overwriting assets..."
        gh release upload "$RELEASE_TAG" \
            "${DIST_ABS}/${BINARY_NAME}"_*.tar.gz "${DIST_ABS}/SHA256SUMS" \
            --repo "$GITHUB_REPO" --clobber
    else
        gh release create "$RELEASE_TAG" \
            "${DIST_ABS}/${BINARY_NAME}"_*.tar.gz "${DIST_ABS}/SHA256SUMS" \
            --repo "$GITHUB_REPO" \
            --title "Middleware GPU Collector ${RELEASE_TAG}" \
            --notes "Middleware GPU OpenTelemetry Collector ${RELEASE_TAG} (linux amd64 + arm64)."
    fi
    log_ok "Published ${RELEASE_TAG}."
fi

echo ""
log_ok "Done. Artifacts in ${DIST_DIR}/:"
ls -1 "$DIST_ABS"
