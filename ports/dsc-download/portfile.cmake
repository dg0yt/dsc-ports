#
# Copyright 2021 Kai Pastor <dg0yt@darc.de>
#
# License: MIT
#
if(VCPKG_CROSSCOMPILING)
    message(FATAL_ERROR "${PORT} is a host-only port; please mark it as a host port in your dependencies.")
endif()

file(INSTALL
  "${CMAKE_CURRENT_LIST_DIR}/vcpkg-port-config.cmake"
  "${CMAKE_CURRENT_LIST_DIR}/dsc_download.cmake"
  "${CMAKE_CURRENT_LIST_DIR}/copyright"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
