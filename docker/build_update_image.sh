#!/usr/bin/env bash
set -euo pipefail

BASE_IMAGE="${BASE_IMAGE:-iebe-music-joao-sep06v1:latest}"
IMAGE_NAME="${1:-iebe-music-update}"
SIF_NAME="${2:-${IMAGE_NAME}.sif}"
GIT_REF="${GIT_REF:-origin/joao/clean-final}"
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null || {
    echo "docker is required" >&2
    exit 1
}
command -v apptainer >/dev/null || {
    echo "apptainer is required" >&2
    exit 1
}

docker image inspect "${BASE_IMAGE}" >/dev/null || {
    echo "Docker base image not found: ${BASE_IMAGE}" >&2
    echo "Import or build the base image before running this script." >&2
    exit 1
}

git -C "${REPOSITORY_ROOT}" fetch origin "${GIT_REF#origin/}"
SOURCE_REV="$(git -C "${REPOSITORY_ROOT}" rev-parse "${GIT_REF}")"

docker build \
    --pull=false \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "GIT_REF=${GIT_REF}" \
    --build-arg "SOURCE_REV=${SOURCE_REV}" \
    --tag "${IMAGE_NAME}:latest" \
    --file "${REPOSITORY_ROOT}/docker/Dockerfile.update-only" \
    "${REPOSITORY_ROOT}"

apptainer build --force "${SIF_NAME}" \
    "docker-daemon:${IMAGE_NAME}:latest"

apptainer exec "${SIF_NAME}" bash -lc \
    'test "$(grep -c "compute_correlation.*: 1" \
       /opt/iEBE-MUSIC/config/design_points/parameters_dict_user_TRENTo_realistic.py)" -eq 1 &&
     strings /opt/iEBE-MUSIC/codes/hadronic_afterburner_toolkit_code/hadronic_afterburner_tools.e |
       grep -Fx compact_spvn >/dev/null'

echo "Built and verified ${SIF_NAME} from ${SOURCE_REV}"
