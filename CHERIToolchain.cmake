SET(CMAKE_SYSTEM_NAME FreeBSD)
SET(CMAKE_SYSTEM_VERSION 10)

SET(CHERI_SDK "/local/scratch/lmp53/cheri/output/sdk256/bin")
SET(SYSROOT "${CHERI_SDK}/../sysroot")
SET(LLVM_PATH "${CHERI_SDK}")
#SET(LLVM_PATH "/home/dc552/CHERISDK/llvm/Debug/bin")
INCLUDE(CMakeForceCompiler)

SET(CMAKE_FORCE_C_COMPILER   "${LLVM_PATH}/clang" Clang)
SET(CMAKE_FORCE_CXX_COMPILER   "${LLVM_PATH}/clang++" Clang)
set(CMAKE_CXX_COMPILER_FORCED TRUE)


# specify the cross compiler
SET(CMAKE_C_COMPILER   "${LLVM_PATH}/clang")
SET(CMAKE_CXX_COMPILER   "${LLVM_PATH}/clang++")
SET(CHERIBSD_COMMON_FLAGS "--sysroot=${SYSROOT} -B${CHERI_SDK} -target cheri-unknown-freebsd -integrated-as -O2 -mabi=purecap -msoft-float -fexceptions -Wno-unused-command-line-argument")
SET(CMAKE_C_FLAGS "${CHERIBSD_COMMON_FLAGS}" CACHE STRING "toolchain_cflags" FORCE)
SET(CMAKE_ASM_FLAGS "${CHERIBSD_COMMON_FLAGS}" CACHE STRING "toolchain_asmflags" FORCE)
SET(CMAKE_CXX_FLAGS "${CHERIBSD_COMMON_FLAGS} -std=c++11" CACHE STRING "toolchain_cxxflags" FORCE)
#SET(CMAKE_LINK_FLAGS "${CHERIBSD_COMMON_FLAGS} -L/home/dc552/tmp/unwind/libunwind/Cheri/lib -lunwind -L/home/dc552/libcxxrt/Build/lib/ -lcxxrt -L." CACHE STRING "toolchain_linkflags" FORCE)
SET(CMAKE_EXE_LINKER_FLAGS "${CHERIBSD_LINK_FLAGS} -L${SYSROOT}/usr/libcheri/" CACHE STRING "toolchain_exe_linkflags" FORCE)
SET(CMAKE_SYSTEM_PROCESSOR "BERI (MIPS IV compatible)")


# where is the target environment 
SET(CMAKE_FIND_ROOT_PATH  ${SYSROOT})

# search for programs in the build host directories
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

