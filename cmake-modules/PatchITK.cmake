# PatchITK.cmake — fix ITK's vendored KWSys for C++20 (removed std::allocator::rebind)
#
# std::allocator::rebind was deprecated in C++17 and removed in C++20, so newer
# libstdc++ (GCC 14/15, e.g. Fedora 44, Ubuntu 26.04) no longer provides
# _Alloc::rebind. ITK release-4.14's KWSys hashtable template then fails:
#   error: no class template named 'rebind' in 'class std::allocator<...>'
# ITK itself builds, but downstream consumers of itksys/hash_map (e.g. Convert3D)
# fail to compile.
#
# Replace the three `typename _Alloc::template rebind<X>::other` typedefs with
# the standard C++11 `std::allocator_traits<_Alloc>::template rebind_alloc<X>`,
# which works on every supported standard. <memory> is already included.
#
# Interim until the ITK pin includes the upstream fix
# (InsightSoftwareConsortium/ITK PR #6513); drop this patch once the pin is
# bumped past that merge.
#
# Expects -DSOURCE_DIR=<path to ITK source>

set(HASHTABLE "${SOURCE_DIR}/Modules/ThirdParty/KWSys/src/KWSys/hashtable.hxx.in")
file(READ "${HASHTABLE}" CONTENT)

string(REGEX REPLACE
  "typename _Alloc::template rebind<([^>]*)>::other"
  "typename std::allocator_traits<_Alloc>::template rebind_alloc<\\1>"
  CONTENT "${CONTENT}")

file(WRITE "${HASHTABLE}" "${CONTENT}")
message(STATUS "Patched ITK KWSys hashtable.hxx.in for C++20 (allocator rebind)")
