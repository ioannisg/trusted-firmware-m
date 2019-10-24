#-------------------------------------------------------------------------------
# Copyright (c) 2019, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#-------------------------------------------------------------------------------

#When included, this file will add a target to build the cc312 libraries with
#the same compilation setting as used by the file including this one.
cmake_minimum_required(VERSION 3.7)

if (CMAKE_HOST_WIN32)
	message(FATAL_ERROR "CC312 build is not supported on windows")
endif()

if (NOT DEFINED CC312_SOURCE_DIR)
	message(FATAL_ERROR "Please set CC312_SOURCE_DIR before including this file.")
endif()

if (NOT DEFINED CC312_TARGET_NAME)
	set(CC312_TARGET_NAME "${PROJECT_NAME}_cc312_lib" PARENT_SCOPE)
	set(CC312_TARGET_NAME "${PROJECT_NAME}_cc312_lib")
	message(WARNING "Using default CC312_TARGET_NAME ${CC312_TARGET_NAME}")
endif()

if (NOT DEFINED CC312_BUILD_DIR)
	set(CC312_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/cryptocell/build")
	message(WARNING "Using default CC312_BUILD_DIR ${CC312_BUILD_DIR}")
endif()

if (NOT DEFINED CC312_INSTALL_DIR)
	set(CC312_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/cryptocell/install PARENT_SCOPE)
	set(CC312_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/cryptocell/install)
	message(WARNING "Using default CC312_INSTALL_DIR ${CC312_INSTALL_DIR}")
endif()


# CC312 needs to know what config mbedtls was built with
if (NOT DEFINED MBEDTLS_CONFIG_FILE)
	message(FATAL_ERROR "Please set MBEDTLS_CONFIG_FILE before including this file.")
endif()
if (NOT DEFINED MBEDTLS_CONFIG_PATH)
	message(FATAL_ERROR "Please set MBEDTLS_CONFIG_PATH before including this file.")
endif()

#FIXME This is bad, but it _does_ work.
if (${PROJECT_NAME} STREQUAL "mcuboot")
	# because these are used in the mbedtls config they need to be defined for
	# CC312 as well (as it includes the config
	if (MCUBOOT_SIGNATURE_TYPE STREQUAL "RSA-3072")
		string(APPEND CC312_C_FLAGS " -DMCUBOOT_SIGN_RSA_LEN=3072")
	elseif(MCUBOOT_SIGNATURE_TYPE STREQUAL "RSA-2048")
		string(APPEND CC312_C_FLAGS " -DMCUBOOT_SIGN_RSA_LEN=2048")
	endif()
endif()


list(APPEND ALL_SRC_C "${PLATFORM_DIR}/common/cc312/cc312.c")

embedded_include_directories(PATH "${PLATFORM_DIR}/common/cc312/" ABSOLUTE)

embedded_include_directories(PATH "${CC312_INSTALL_DIR}/include")
string(APPEND MBEDCRYPTO_C_FLAGS " -I ${CC312_INSTALL_DIR}/include")
string(APPEND CC312_C_FLAGS   " -I ${CC312_INSTALL_DIR}/include")

string(APPEND MBEDCRYPTO_C_FLAGS " -I ${PLATFORM_DIR}/common/cc312")
string(APPEND MBEDTLS_C_FLAGS " -DUSE_MBEDTLS_CRYPTOCELL")
string(APPEND MBEDCRYPTO_C_FLAGS " -DCRYPTO_HW_ACCELERATOR")

string(APPEND MBEDCRYPTO_C_FLAGS " -DMBEDTLS_ECDH_LEGACY_CONTEXT")

string(APPEND CC312_C_FLAGS " -DMBEDTLS_CONFIG_FILE=\'\\\\\\\"${MBEDTLS_CONFIG_FILE}\\\\\\\"\'")
string(APPEND CC312_C_FLAGS " -I ${MBEDTLS_CONFIG_PATH}")
string(APPEND CC312_C_FLAGS " -I ${PLATFORM_DIR}/common/cc312")

string(APPEND CC312_C_FLAGS " -DUSE_MBEDTLS_CRYPTOCELL")
string(APPEND CC312_C_FLAGS " -DCRYPTO_HW_ACCELERATOR")

if (MBEDCRYPTO_DEBUG)
	if (${COMPILER} STREQUAL "GNUARM")
		list(APPEND ALL_SRC_C "${PLATFORM_DIR}/common/cc312/cc312_log.c")
		string(APPEND CC312_C_FLAGS " -DDEBUG -DCC_PAL_MAX_LOG_LEVEL=3")
	else()
        # Can't set DEBUG (because of stdout issues)
		message(WARNING "${COMPILER} does not support CC312 debug logging")
	endif()
	string(APPEND CC312_C_FLAGS " -g -O0")
endif()

set(CC312_COMPILER ${CMAKE_C_COMPILER})

if (${COMPILER} STREQUAL "ARMCLANG")
	set(CC312_CROSSCOMPILE armclang)
elseif(${COMPILER} STREQUAL "GNUARM")
	set(CC312_CROSSCOMPILE arm-none-eabi-)
else()
	message(FATAL_ERROR "Compiler ${COMPILER} is not supported by CC312")
endif()

# Because a makefile is being called anything defined here will prevent
# modification in the makefile. Due to this the extra flags are included as part
# of the compiler directive (which won't be modified, where the actual CFLAGS
# variable will).
#
# Variables split between here and CC312_CFG.mk. Anything that depends on a
# cmake variable is set here.
set(CC312_ENV "\
 ARCH=arm\
 CC='${CC312_COMPILER} ${CC312_C_FLAGS}'\
 CROSS_COMPILE=${CC312_CROSSCOMPILE}\
 MBEDCRYPTO_ROOT_DIR=${MBEDCRYPTO_SOURCE_DIR}\
 MBEDCRYPTO_ROOT=${MBEDCRYPTO_SOURCE_DIR}\
 PROJ_CFG_PATH=${PLATFORM_DIR}/common/cc312/cc312_proj_cfg.mk\
 BUILDDIR=${CC312_BUILD_DIR}/\
 RELEASE_LIBDIR=${CC312_INSTALL_DIR}/lib/\
 RELEASE_INCDIR=${CC312_INSTALL_DIR}/include/\
 LOGFILE=${CMAKE_CURRENT_BINARY_DIR}/cc312_makelog.txt\
")

if (TARGET ${CC312_TARGET_NAME})
	message(FATAL_ERROR "A target with name ${CC312_TARGET_NAME} is already\
defined. Please set CC312_TARGET_NAME to a unique value.")
endif()

#Build CC312 as external project.
include(ExternalProject)
set(_static_lib_command ${CMAKE_C_CREATE_STATIC_LIBRARY})
externalproject_add(${CC312_TARGET_NAME}
	SOURCE_DIR ${CC312_SOURCE_DIR}/host/src
	CMAKE_ARGS -DCMAKE_BUILD_TYPE=${CC312_BUILD_TYPE}
	BUILD_IN_SOURCE 1
	DOWNLOAD_COMMAND ""
	UPDATE_COMMAND ""
	WORKING_DIRECTORY ${CC312_SOURCE_DIR}/host/src
	CONFIGURE_COMMAND ${CMAKE_COMMAND} -E make_directory ${CC312_SOURCE_DIR}/mbedtls
		COMMAND  ${CMAKE_COMMAND} -E copy_directory ${MBEDCRYPTO_SOURCE_DIR} ${CC312_SOURCE_DIR}/mbedtls
	INSTALL_COMMAND ""
	BUILD_ALWAYS TRUE
	BUILD_COMMAND bash -c "make -C ${CC312_SOURCE_DIR}/host/src ${CC312_ENV}")
