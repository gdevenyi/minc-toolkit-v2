#!/bin/bash
# THROWAWAY CI check for BIC-MNI/libminc #152 + #154 + #155 + #156. Do not merge.
#
# Install the toolkit into a staging directory, then build a separate project
# against the installed LIBMINC::minc2 and LIBMINC::nifti, as an external tool
# such as falcon does (BIC-MNI/minc-toolkit-v2#245, #247).
#
# Usage: ci-libminc-nifti-consumer.sh [build-dir]
set -euxo pipefail

build=${1:-build}
stage=$PWD/ci-stage
rm -rf "$stage"
DESTDIR="$stage" cmake --install "$build" > "$PWD/ci-stage-install.log"

cfg=$(find "$stage" -path '*/cmake/LIBMINCConfig.cmake' | head -n 1)
test -n "$cfg"
prefix=$(cd "$(dirname "$cfg")/../.." && pwd)
ls "$prefix/include/nifti"

src=$PWD/ci-consumer
rm -rf "$src"
mkdir -p "$src"
cat > "$src/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(libminc_nifti_consumer C)
find_package(LIBMINC CONFIG REQUIRED)
add_executable(m m.c)
target_link_libraries(m PRIVATE LIBMINC::minc2)
# LIBMINC::minc2 does not carry a system HDF5 include dir (Debian keeps
# hdf5.h in /usr/include/hdf5/serial); the legacy variable does. Known
# gap, separate from the NIfTI work.
target_include_directories(m PRIVATE ${LIBMINC_INCLUDE_DIRS})
add_executable(n n.c)
target_link_libraries(n PRIVATE LIBMINC::nifti)
EOF
cat > "$src/m.c" <<'EOF'
#include <minc2.h>
int main(void) { mihandle_t h; return miopen_volume("x.mnc", MI2_OPEN_READ, &h) == MI_NOERROR; }
EOF
cat > "$src/n.c" <<'EOF'
#include <nifti1_io.h>
int main(int argc, char **argv) {
  nifti_image *nim = nifti_image_read(argc > 1 ? argv[1] : "x.nii", 0);
  if (nim) nifti_image_free(nim);
  return 0;
}
EOF

cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release \
  -DLIBMINC_DIR="$(dirname "$cfg")" -DCMAKE_PREFIX_PATH="$prefix"
cmake --build "$src/build"

# The NIfTI call must go to libminc's renamed symbol, and no unrenamed
# nifti_* / znz* name may remain in the program.
nm "$src/build/n" | grep -E ' U _?minc_nifti_image_read$'
if nm "$src/build/n" | grep -E ' [TtUu] _?(nifti|znz|Xznz)[A-Za-z0-9_]*$'; then
  echo "unrenamed NIfTI symbol in the consumer" >&2
  exit 1
fi
echo "OK: LIBMINC::minc2 and LIBMINC::nifti link against the installed toolkit"
