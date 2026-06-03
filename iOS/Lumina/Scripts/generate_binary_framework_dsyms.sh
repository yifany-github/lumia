#!/bin/sh
set -eu

# Xcode can omit dSYMs for SwiftPM binary frameworks during Archive upload.
# Generate matching UUID dSYMs from the embedded iOS binaries so App Store
# Connect can ingest the archive without "Upload Symbols Failed" warnings.

if [ "${ACTION:-}" != "install" ]; then
  exit 0
fi

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  exit 0
fi

mkdir -p "${DWARF_DSYM_FOLDER_PATH}"

frameworks="
FirebaseFirestoreInternal
absl
grpc
grpcpp
openssl_grpc
"

derived_data_root="${BUILD_DIR%%/Build/*}"
source_packages_artifacts="${derived_data_root}/SourcePackages/artifacts"
embedded_frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH:-Frameworks}"

find_framework_binary() {
  name="$1"

  if [ -f "${embedded_frameworks_dir}/${name}.framework/${name}" ]; then
    printf '%s\n' "${embedded_frameworks_dir}/${name}.framework/${name}"
    return 0
  fi

  if [ -d "${source_packages_artifacts}" ]; then
    found="$(find "${source_packages_artifacts}" \
      -path "*/ios-arm64/${name}.framework/${name}" \
      -type f \
      -print \
      -quit)"
    if [ -n "${found}" ]; then
      printf '%s\n' "${found}"
      return 0
    fi
  fi

  return 1
}

for framework in ${frameworks}; do
  dsym_path="${DWARF_DSYM_FOLDER_PATH}/${framework}.framework.dSYM"
  if [ -d "${dsym_path}" ]; then
    continue
  fi

  binary_path="$(find_framework_binary "${framework}" || true)"
  if [ -z "${binary_path}" ]; then
    echo "warning: ${framework}.framework binary was not found for dSYM generation"
    continue
  fi

  echo "Generating ${framework}.framework.dSYM"
  dsymutil "${binary_path}" -o "${dsym_path}"
done
