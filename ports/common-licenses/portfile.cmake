#
# Copyright 2021 Kai Pastor <dg0yt@darc.de>
#
# License: MIT
#
# https://tracker.debian.org/pkg/base-files

dsc_download(
  PACKAGE  base-files
  VERSION  11.1
  SHA512   4aa64b6a066e71b4edeb68f9640911c83a6b1f9d8f98b93160dbd7b81a18e3a5969986549936df156089cc196e48523c1121f2e8fc131862254f1f8af4ef04eb
  SNAPSHOT 20210411T023434Z
  OUT_SOURCE_PATH source_path
)

file(GLOB files "${source_path}/licenses/*")
foreach(file ${files})
    get_filename_component(filename "${file}" NAME)
    string(REGEX REPLACE "[^-a-zA-Z0-9]" "-" name "${filename}")
    string(TOLOWER "${name}" feature)
    if(feature IN_LIST FEATURES)
        file(
          INSTALL "${file}"
          DESTINATION "${CURRENT_PACKAGES_DIR}/share/common-licenses"
        )
    endif()
endforeach()

set(copyright "")
if(";${FEATURES}" MATCHES ";artistic")
    string(APPEND copyright [[
The Artistic License is from Perl.
Its SPDX name is "Artistic License 1.0 (Perl)".
        
]])        
endif()
if(";${FEATURES}" MATCHES ";(gpl|lgpl|gfdl)")
    string(APPEND copyright [[
The GNU Public Licenses were taken from ftp.gnu.org.
They are copyrighted by the Free Software Foundation, Inc.
        
]])        
endif()
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "${copyright}")

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
