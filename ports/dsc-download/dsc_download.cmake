#
# Copyright 2021 Kai Pastor <dg0yt@darc.de>
#
# License: MIT
#
#[===[

# dsc_download

Download a Debian dsc file, fetch and extract all source files.

## Usage
```cmake
dsc_download(
  VERSION <1.0.1-1>
  SHA512 <ba987654...>
  SNAPSHOT <20190128T030507Z>
  PATCHES <relocatable.patch>
  OUT_SOURCE_PATH <OUT_VARIABLE>
)
```
## Parameters
### OUT_SOURCE_PATH
This variable will be set to the full path to the extracted and patched archive.
The result can then immediately be passed in to `vcpkg_cmake_configure` etc.

### PACKAGE
The name of the debian source package.

This parameter is optional. The default value is the name of the port.

### VERSION
The full version of the debian source package

### SHA512
The expected hash for the dsc file.

If this doesn't match the downloaded version, the build will be terminated with a message describing the mismatch.

### COMPONENT
The component of the Debian distribution where the package is found (`main`, `contrib` or `non-free`).
If unset, the default value is `main`.

### BASE_URLS
Provide base URLs which should be tried first.

These URLs must be complete including trailing slash so that only the filename needs to be appended.

### NO_DEFAULT_URLS
This flag disables the download from the standard Debian servers.

Use this option when the package is not or no longer in a current Debian distribution.

### SNAPSHOT
The timestamp/directory of snapshots.debian.org where this package can be found
even when it is no longer on the regular debian servers.
If set, the snapshot service is used when the package is no longer available on the main servers.

### PATCHES
A list of patches to be applied to the extracted sources in addition to Debian's patches

Relative paths are based on the port directory.

]===]


if(Z_DSC_DOWNLOAD_INSTALL_GUARD)
    return()
endif()
set(Z_DSC_DOWNLOAD_INSTALL_GUARD ON CACHE INTERNAL "include guard")

function(z_dpkg_get_patches var archive)
    set(patches )
    set(series )
    if (EXISTS "${archive}/patches/series")
        file(STRINGS "${archive}/patches/series" series)
    endif()
    foreach(line ${series})
        string(STRIP "${line}" line)
        if(NOT line MATCHES "^#")
            list(APPEND patches "${line}")
        endif()
    endforeach()
    set(${var} ${patches} PARENT_SCOPE)
endfunction()

function(z_dpkg_check_archive)
    set(options SILENT_EXIT)
    set(oneValueArgs OUT_RESULT FILENAME SHA256 SIZE)
    set(multipleValuesArgs "")
    cmake_parse_arguments(PARSE_ARGV 0 ZDCA "${options}" "${oneValueArgs}" "${multipleValuesArgs}")

    if(NOT DEFINED ZDCA_FILENAME)
        message(FATAL_ERROR "z_dpkg_check_archive requires a FILENAME argument.")
    endif()
    if(NOT DEFINED ZDCA_SHA256)
        message(FATAL_ERROR "z_dpkg_check_archive requires a SHA256 argument.")
    endif()
    if(ZDCA_SILENT_EXIT AND NOT DEFINED ZDCA_OUT_RESULT)
        message(FATAL_ERROR "z_dpkg_check_archive requires a an OUT_RESULT argument when SILENT_EXIT is used.")
    endif()

    if(ZDCA_SILENT_EXIT)
        set(message_class STATUS)
    else()
        set(message_class FATAL_ERROR)
    endif()

    set(result TRUE)
    if(ZDCA_SIZE)
        file(SIZE "${download}" file_size)
        if(NOT file_size STREQUAL ZDCA_SIZE)
            message(${message_class}
              "File does not have expected size:\n"
              "        File path: [ ${download} ]\n"
              "    Expected size: [ ${ZDCA_SIZE} ]\n"
              "      Actual size: [ ${file_size} ]"
            )
            set(result FALSE)
        endif()
    endif()

    file(SHA256 "${download}" file_hash)
    if(NOT file_hash STREQUAL ZDCA_SHA256)
        message(${message_class}
          "File does not have expected hash:\n"
          "        File path: [ ${download} ]\n"
          "    Expected hash: [ ${ZDCA_SHA256} ]\n"
          "      Actual hash: [ ${file_hash} ]"
        )
        set(result FALSE)
    endif()

    if(ZDCA_OUT_RESULT)
        set(${ZDCA_OUT_RESULT} "${result}" PARENT_SCOPE)
    endif()
endfunction()

function(z_dpkg_archive_download VAR)
    set(options "")
    set(oneValueArgs FILENAME SHA256 SIZE)
    set(multipleValuesArgs BASEURLS)
    cmake_parse_arguments(PARSE_ARGV 1 ZDAD "${options}" "${oneValueArgs}" "${multipleValuesArgs}")

    if(NOT DEFINED ZDAD_FILENAME)
        message(FATAL_ERROR "z_dpkg_archive_download requires a FILENAME argument.")
    endif()
    if(NOT DEFINED ZDAD_BASEURLS)
        message(FATAL_ERROR "z_dpkg_archive_download requires a BASEURLS argument.")
    endif()
    if(NOT DEFINED ZDAD_SHA256)
        message(FATAL_ERROR "z_dpkg_archive_download requires a SHA256 argument.")
    endif()

    list(TRANSFORM ZDAD_BASEURLS
      APPEND "${ZDAD_FILENAME}"
      OUTPUT_VARIABLE urls
    )

    # Two attempts in order to avoid assumptions about download location.
    set(_VCPKG_INTERNAL_NO_HASH_CHECK 1)
    foreach(check_arg IN ITEMS "SILENT_EXIT" "")
        vcpkg_download_distfile(download
          URLS ${urls}
          FILENAME "${ZDAD_FILENAME}"
          SKIP_SHA512
        )
        z_dpkg_check_archive(
          FILENAME   "${download}"
          SHA256     "${ZDAD_SHA256}"
          SIZE       "${ZDAD_SIZE}"
          OUT_RESULT success
          ${check_arg}
        )
        if(NOT success AND EXISTS "${download}")
            message(STATUS "Removing invalid '${download}'.")
            file(REMOVE "${download}")
        endif()
    endforeach()
    set(${VAR} "${download}" PARENT_SCOPE)
endfunction()

function(z_dpkg_source_download)
    set(options "")
    set(oneValueArgs DSCFILE OUT_ARCHIVES OUT_FORMAT VENDOR)
    set(multipleValuesArgs BASEURLS PATCHES)
    cmake_parse_arguments(PARSE_ARGV 0 ZDSD "${options}" "${oneValueArgs}" "${multipleValuesArgs}")

    if(NOT DEFINED ZDSD_OUT_ARCHIVES)
        message(FATAL_ERROR "z_dpkg_source_download requires an OUT_ARCHIVES argument.")
    endif()
    if(NOT DEFINED ZDSD_DSCFILE)
        message(FATAL_ERROR "z_dpkg_source_download requires a DSCFILE argument.")
    endif()
    if(NOT DEFINED ZDSD_BASEURLS)
        message(FATAL_ERROR "z_dpkg_source_download requires a BASEURLS argument.")
    endif()

    get_filename_component(file "${ZDSD_DSCFILE}" ABSOLUTE BASE_DIR "${CURRENT_PORT_DIR}")
    file(STRINGS "${file}" lines)

    set(in_checksums FALSE)
    set(archives )
    set(downloads )
    set(format )
    foreach(line IN LISTS lines)
        if(line MATCHES "^Format: *(.*[^ ]) *$")
            set(format "${CMAKE_MATCH_1}")
        elseif(line MATCHES "^Checksums-Sha256:")
            set(in_checksums TRUE)
        elseif(in_checksums AND line MATCHES "^ ")
            list(APPEND archives "${line}")
        elseif(in_checksums)
            break()
        endif()
    endforeach()
    foreach(archive IN LISTS archives)
        string(REGEX MATCH "^ *([^ ]*)  *([^ ]*)  *([^ ]*)" unused "${archive}")
        z_dpkg_archive_download(download
          BASEURLS ${ZDSD_BASEURLS}
          SHA256   "${CMAKE_MATCH_1}"
          SIZE     "${CMAKE_MATCH_2}"
          FILENAME "${CMAKE_MATCH_3}"
        )
        list(APPEND downloads "${download}")
    endforeach()

    set(${ZDSD_OUT_ARCHIVES} "${downloads}" PARENT_SCOPE)
    if(DEFINED ZDSD_OUT_FORMAT)
        set(${ZDSD_OUT_FORMAT} "${format}" PARENT_SCOPE)
    endif()
endfunction()

# Cf. dpkg-source -x,
# Cf. https://manpages.debian.org/testing/dpkg-dev/dpkg-source.1.en.html
function(z_dpkg_source_extract)
    set(options "")
    set(oneValueArgs OUT_SOURCE_PATH)
    set(multipleValuesArgs ARCHIVES FORMAT PATCHES)
    cmake_parse_arguments(PARSE_ARGV 0 ZDSE "${options}" "${oneValueArgs}" "${multipleValuesArgs}")

    if(NOT DEFINED ZDSE_OUT_SOURCE_PATH)
        message(FATAL_ERROR "z_dpkg_source_extract requires an OUT_SOURCE_PATH argument.")
    endif()
    if(NOT DEFINED ZDSE_ARCHIVES)
        message(FATAL_ERROR "z_dpkg_source_extract requires an ARCHIVES argument.")
    endif()
    if(NOT DEFINED ZDSE_FORMAT)
        set(ZDSE_FORMAT "3.0 (quilt)")  # Reasonable default
    endif()

    # Unsupported: detached upstream signature
    list(FILTER ZDSE_ARCHIVES EXCLUDE REGEX "\\.asc$")

    if(ZDSE_FORMAT STREQUAL "3.0 (native)")
        set(orig_component "${ZDSE_ARCHIVES}")
        list(FILTER orig_component INCLUDE REGEX "\\.tar\\.")
        list(FILTER ZDSE_ARCHIVES EXCLUDE REGEX "\\.tar\\.")
        vcpkg_extract_source_archive_ex(
          OUT_SOURCE_PATH root
          ARCHIVE ${orig_component}
          REF "orig"
        )
    elseif(ZDSE_FORMAT STREQUAL "3.0 (quilt)")
        foreach(component "orig" "debian")
            set(${component}_component "${ZDSE_ARCHIVES}")
            list(FILTER ${component}_component INCLUDE REGEX "\\.${component}\\.tar\\.")
            list(FILTER ZDSE_ARCHIVES EXCLUDE REGEX "\\.${component}\\.tar\\.")
        endforeach()

        vcpkg_extract_source_archive_ex(
          OUT_SOURCE_PATH debian
          ARCHIVE ${debian_component}
          REF "debian"
        )
        z_dpkg_get_patches(debian_patches ${debian})
        vcpkg_extract_source_archive_ex(
          OUT_SOURCE_PATH root
          ARCHIVE ${orig_component}
          REF "orig"
          PATCHES ${debian_patches} ${ZDSE_PATCHES}
        )
        if(EXISTS "${root}/debian")
            file(REMOVE_RECURSE "${root}/debian")
        endif()
        file(RENAME "${debian}" "${root}/debian")
    else()
        message(FATAL_ERROR "Unsupported source package format: ${ZDSE_FORMAT}")
    endif()

    if(ZDSE_ARCHIVES)
        message(WARNING "Unhandled sidecar files: ${ZDSE_ARCHIVES}")
    endif()

    set(${ZDSE_OUT_SOURCE_PATH} "${root}" PARENT_SCOPE)
endfunction()

function(dsc_download)
    set(options NO_DEFAULT_URLS)
    set(oneValueArgs OUT_SOURCE_PATH PACKAGE VERSION SHA512 COMPONENT SNAPSHOT)
    set(multipleValuesArgs BASE_URLS PATCHES)
    cmake_parse_arguments(PARSE_ARGV 0 DSC_DOWNLOAD "${options}" "${oneValueArgs}" "${multipleValuesArgs}")

    if(NOT DEFINED DSC_DOWNLOAD_OUT_SOURCE_PATH)
        message(FATAL_ERROR "dpkg_from_dsc requires an OUT_SOURCE_PATH argument.")
    endif()
    if(NOT DEFINED DSC_DOWNLOAD_SHA512)
        message(FATAL_ERROR "dpkg_from_dsc requires an SHA512 argument.")
    endif()

    if(NOT DEFINED DSC_DOWNLOAD_PACKAGE)
        set(DSC_DOWNLOAD_PACKAGE "${PORT}")
    endif()

    if(NOT DEFINED DSC_DOWNLOAD_COMPONENT)
        set(DSC_DOWNLOAD_COMPONENT "main")
    endif()

    string(REGEX REPLACE "^(lib[a-z0-9]|[a-z0-9]).*" "\\1" dir "${DSC_DOWNLOAD_PACKAGE}")
    set(subpath "${DSC_DOWNLOAD_COMPONENT}/${dir}/${DSC_DOWNLOAD_PACKAGE}")
    set(dsc_file "${DSC_DOWNLOAD_PACKAGE}_${DSC_DOWNLOAD_VERSION}.dsc")

    set(base_urls "")
    if(DCI_BASE_URLS)
        list(APPEND base_urls ${DCI_BASE_URLS})
    endif()
    if(NOT DCI_NO_DEFAULT_URLS)
        list(APPEND "https://ftp.debian.org/debian/pool/${subpath}/")
    endif()
    if(DSC_DOWNLOAD_SNAPSHOT)
        list(APPEND base_urls "https://snapshot.debian.org/archive/debian/${DSC_DOWNLOAD_SNAPSHOT}/pool/${subpath}/")
    endif()

    # Download the dsc file
    foreach(base_url IN LISTS base_urls)
        set(downloaded_dsc_file FALSE)
        vcpkg_download_distfile(downloaded_dsc_file
          URLS "${base_url}${dsc_file}"
          FILENAME "${dsc_file}"
          SHA512 "${DSC_DOWNLOAD_SHA512}"
          SILENT_EXIT
        )
        if(downloaded_dsc_file)
            break()
        else()
            list(REMOVE_ITEM base_urls "${base_url}")
        endif()
    endforeach()
    if(NOT downloaded_dsc_file)
        message(FATAL_ERROR "Unable to download '${dsc_file}' from ${base_urls}.")
    endif()
    # Download actual sources
    z_dpkg_source_download(
      OUT_ARCHIVES archives
      OUT_FORMAT format
      DSCFILE "${downloaded_dsc_file}"
      BASEURLS ${base_urls}
    )
    # Extract and patch
    z_dpkg_source_extract(
      OUT_SOURCE_PATH root
      ARCHIVES ${archives}
      FORMAT  "${format}"
      PATCHES ${DSC_DOWNLOAD_PATCHES}
    )
    set(${DSC_DOWNLOAD_OUT_SOURCE_PATH} "${root}" PARENT_SCOPE)
endfunction()

