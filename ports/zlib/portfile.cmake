#
# Copyright 2021 Kai Pastor <dg0yt@darc.de>
#
# License: MIT
#
# https://tracker.debian.org/pkg/zlib
# https://tracker.debian.org/pkg/libz-mingw-w64

dsc_download(
  PACKAGE   libz-mingw-w64  # zlib source package is missing some files
  VERSION   1.2.11+dfsg-2
  SHA512    9cc7ed7147210fadb35f2ecf0eaf24c86cbcf6c1cd332dda32d901d14321555a37b2d364c5eee68bd822d46eaad9837fa10fce9d65b7aad2567a20be274e5d6f
  SNAPSHOT  20210320T204911Z
  PATCHES
    cmake_dont_build_more_than_needed.patch
  OUT_SOURCE_PATH source_path
)

# This is generated during the cmake build
file(REMOVE "${source_path}/zconf.h")

vcpkg_cmake_configure(
  SOURCE_PATH "${source_path}"
  OPTIONS
    -DSKIP_BUILD_EXAMPLES=ON
  OPTIONS_RELEASE
    -DINSTALL_PKGCONFIG_DIR=${CURRENT_PACKAGES_DIR}/lib/pkgconfig
  OPTIONS_DEBUG
    -DINSTALL_PKGCONFIG_DIR=${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig
    -DSKIP_INSTALL_HEADERS=ON
)

vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${source_path}/debian/copyright"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
