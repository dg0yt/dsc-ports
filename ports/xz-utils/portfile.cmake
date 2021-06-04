#
# Copyright 2021 Kai Pastor <dg0yt@darc.de>
#
# License: MIT
#
# https://tracker.debian.org/pkg/xz-utils

dsc_download(
  VERSION   5.2.4-1
  SHA512    11c0c0cd0d8c93b87a8fd56bb677f01b32fd73a47380f2b189018d5d94bfdc27d898778c06014c5e201a52f0b2a2b132fc79b51691d5f6de5cc1d8633aff690e
  SNAPSHOT  20190128T030507Z
  OUT_SOURCE_PATH source_path
)

set(FEATURE_OPTIONS "")
if(NOT "tools" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS
      --disable-xz
      --disable-xzdec
      --disable-lzmadec
      --disable-lzmainfo
      --disable-scripts
    )
endif()
vcpkg_configure_make(
  SOURCE_PATH "${source_path}"
  OPTIONS
    --disable-lzma-links
    --disable-doc
    ${FEATURE_OPTIONS}
)

vcpkg_install_make()
vcpkg_fixup_pkgconfig()

file(GLOB_RECURSE bin_files "${CURRENT_PACKAGES_DIR}/tools/*")
if(bin_files STREQUAL "")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/tools")
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${source_path}/debian/copyright"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
