#!/bin/bash
# Build script for Serviio 2.5 Synology DSM 7.x SPK package
#
# Downloads all binary dependencies automatically into .cache/.
#
# Usage:
#   chmod +x build.sh
#   ./build.sh

set -e

PACKAGE_NAME="Serviio"
PACKAGE_VERSION="2.5-0002"
OUTPUT_FILE="${PACKAGE_NAME}-${PACKAGE_VERSION}.spk"
BUILD_DIR="$(mktemp -d)"
CACHE_DIR="$(pwd)/.cache"

SERVIIO_DIR="${CACHE_DIR}/serviio-2.5"
JRE_DIR="${CACHE_DIR}/jre"

# ── Dependency versions ───────────────────────────────────────────────────────
SERVIIO_VERSION="2.5"
SERVIIO_ARCHIVE="serviio-${SERVIIO_VERSION}-linux.tar.gz"
SERVIIO_URL="http://download.serviio.org/releases/${SERVIIO_ARCHIVE}"

TEMURIN_VERSION="11.0.23+9"
TEMURIN_VERSION_SAFE="11.0.23_9"   # underscore form used in filenames
TEMURIN_ARCHIVE="OpenJDK11U-jre_x64_linux_hotspot_${TEMURIN_VERSION_SAFE}.tar.gz"
TEMURIN_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${TEMURIN_VERSION/+/%2B}/${TEMURIN_ARCHIVE}"

# ── Download helpers ──────────────────────────────────────────────────────────
download() {
    local url="$1" dest="$2"
    echo "    Downloading $(basename "${dest}")..."
    curl -fL --progress-bar -o "${dest}" "${url}"
}

ensure_serviio() {
    if [ -d "${SERVIIO_DIR}" ]; then
        echo "==> Serviio ${SERVIIO_VERSION} already in .cache/"
        return
    fi

    mkdir -p "${CACHE_DIR}"
    local archive="${CACHE_DIR}/${SERVIIO_ARCHIVE}"

    if [ ! -f "${archive}" ]; then
        echo "==> Downloading Serviio ${SERVIIO_VERSION}..."
        download "${SERVIIO_URL}" "${archive}" || {
            echo ""
            echo "ERROR: Could not download Serviio automatically."
            echo "       Download serviio-${SERVIIO_VERSION}-linux.tar.gz manually from:"
            echo "       https://serviio.org/download"
            echo "       and place it at: ${archive}"
            echo "       OR extract it directly to: ${SERVIIO_DIR}/"
            rm -f "${archive}"
            exit 1
        }
    fi

    echo "==> Extracting Serviio ${SERVIIO_VERSION}..."
    mkdir -p "${SERVIIO_DIR}"
    tar -xzf "${archive}" --strip-components=1 -C "${SERVIIO_DIR}"
}

ensure_jre() {
    if [ -d "${JRE_DIR}" ]; then
        echo "==> JRE already in .cache/"
        return
    fi

    mkdir -p "${CACHE_DIR}"
    local archive="${CACHE_DIR}/${TEMURIN_ARCHIVE}"

    if [ ! -f "${archive}" ]; then
        echo "==> Downloading Eclipse Temurin JRE ${TEMURIN_VERSION}..."
        download "${TEMURIN_URL}" "${archive}"
    fi

    echo "==> Extracting JRE..."
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    tar -xzf "${archive}" -C "${tmp_dir}"

    set -- "${tmp_dir}"/*/
    local extracted="$1"
    if [ ! -d "${extracted}" ]; then
        rm -rf "${tmp_dir}"
        echo "ERROR: unexpected layout in ${TEMURIN_ARCHIVE} — no top-level directory" >&2
        exit 1
    fi

    mv "${extracted}" "${JRE_DIR}"
    rm -rf "${tmp_dir}"
}

# ── Fetch dependencies ────────────────────────────────────────────────────────
ensure_serviio
ensure_jre

echo "==> Building ${OUTPUT_FILE}"

# ── Build package.tgz ────────────────────────────────────────────────────────
echo "==> Assembling package root..."
PKG_ROOT="${BUILD_DIR}/package_root"
mkdir -p "${PKG_ROOT}/serviio"

cp -r "${SERVIIO_DIR}/." "${PKG_ROOT}/serviio/"

# Extract serviio.properties from inside the JAR, then patch Windows paths to Linux
unzip -p "${PKG_ROOT}/serviio/lib/serviio.jar" serviio.properties \
    > "${PKG_ROOT}/serviio/config/serviio.properties"
sed -i 's|ffmpeg_executable=.*|ffmpeg_executable=/usr/bin/ffmpeg|' "${PKG_ROOT}/serviio/config/serviio.properties"
sed -i 's|dcraw_executable=.*|dcraw_executable=/usr/bin/dcraw|'   "${PKG_ROOT}/serviio/config/serviio.properties"

# Replace log4j2.xml to write logs to the writable data dir instead of the install dir
cp "$(pwd)/overrides/log4j2.xml" "${PKG_ROOT}/serviio/config/log4j2.xml"

echo "==> Bundling JRE..."
cp -r "${JRE_DIR}" "${PKG_ROOT}/serviio/jre"

# Remove Windows files
find "${PKG_ROOT}" -name "*.bat" -delete
find "${PKG_ROOT}" -name "*.exe" -delete

chmod +x "${PKG_ROOT}/serviio/bin/serviio.sh"         2>/dev/null || true
chmod +x "${PKG_ROOT}/serviio/bin/serviio-console.sh" 2>/dev/null || true

echo "==> Creating package.tgz..."
tar -czf "${BUILD_DIR}/package.tgz" -C "${PKG_ROOT}" .

# ── Copy metadata ────────────────────────────────────────────────────────────
cp "$(pwd)/INFO" "${BUILD_DIR}/INFO"

# ── Copy scripts ─────────────────────────────────────────────────────────────
mkdir -p "${BUILD_DIR}/scripts"
cp "$(pwd)/scripts/start-stop-status" "${BUILD_DIR}/scripts/start-stop-status"
chmod +x "${BUILD_DIR}/scripts/start-stop-status"

# ── Copy icon ───────────────────────────────────────────────────────────────
if [ -f "$(pwd)/icons/PACKAGE_ICON.PNG" ]; then
    cp "$(pwd)/icons/PACKAGE_ICON.PNG"     "${BUILD_DIR}/PACKAGE_ICON.PNG"
fi

# ── Copy conf (DSM 7 privilege config) ───────────────────────────────────────
mkdir -p "${BUILD_DIR}/conf"
cp "$(pwd)/conf/privilege" "${BUILD_DIR}/conf/privilege"

# ── Pack into .spk ───────────────────────────────────────────────────────────
echo "==> Creating ${OUTPUT_FILE}..."
OUTPUT_PATH="$(pwd)/${OUTPUT_FILE}"

PACK_FILES="INFO package.tgz scripts conf"
[ -f "${BUILD_DIR}/PACKAGE_ICON.PNG" ]     && PACK_FILES="${PACK_FILES} PACKAGE_ICON.PNG"
tar -cf "${OUTPUT_PATH}" -C "${BUILD_DIR}" ${PACK_FILES}

rm -rf "${BUILD_DIR}"

echo "==> Done! Package written to: ${OUTPUT_PATH}"
