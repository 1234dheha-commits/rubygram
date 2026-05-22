#!/bin/sh

set -e
set -x

ARCH="$1"

SOURCE_DIR="$2"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")
OPENSSL_DIR="$4"

openssl_crypto_library="${OPENSSL_DIR}/lib/libcrypto.a"
options=""
options="$options -DOPENSSL_FOUND=1"
options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/src/include"
options="$options -DCMAKE_BUILD_TYPE=Release"
options="$options -DIOS_DEPLOYMENT_TARGET=13.0"

cd "$BUILD_DIR"

# Rubygram: disable ccache — Codemagic has it in /opt/homebrew/bin which is outside
# bazel's sandbox PATH, so cmake "finds" it then make fails with "ccache: command not found".
DISABLE_CCACHE_FLAGS="-DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER= -DCMAKE_DISABLE_FIND_PACKAGE_CCache=TRUE"

# Generate source files
mkdir native-build
cd native-build
cmake $DISABLE_CCACHE_FLAGS -DTD_GENERATE_SOURCE_FILES=ON ../td
cmake --build . -- -j$(sysctl -n hw.ncpu)
cd ..

if [ "$ARCH" = "arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneOS.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneOS*.sdk)
  export CFLAGS="-arch arm64 --target=arm64-apple-ios13.0 -miphoneos-version-min=13.0"
elif [ "$ARCH" = "sim_arm64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/iPhoneSimulator.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/iPhoneSimulator*.sdk)
  export CFLAGS="-arch arm64 --target=arm64-apple-ios13.0-simulator -miphonesimulator-version-min=13.0"
else
  echo "Unsupported architecture $ARCH"
  exit 1
fi

# Common build steps
mkdir build
cd build

touch toolchain.cmake
echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

cmake -G"Unix Makefiles" $DISABLE_CCACHE_FLAGS -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} ../td $options
make tde2e -j$(sysctl -n hw.ncpu)
