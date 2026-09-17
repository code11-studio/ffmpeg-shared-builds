#!/bin/bash
# Not a BtbN stage: prepare.sh copies it into scripts.d for the audio-lgpl flavour.
# codec2 (LGPL v2.1): the low-bitrate speech codec of .c2 files, decoded through FFmpeg's libcodec2 wrapper.

SCRIPT_REPO="https://github.com/drowe67/codec2.git"
SCRIPT_COMMIT="06d4c11e699b0351765f10398abb4f663a984f36"   # tag 1.2.0

ffbuild_depends() {
    echo base
}

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cmake -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" -DBUILD_SHARED_LIBS=OFF -DUNITTEST=OFF -DLPCNET=OFF ..

    # When cross-compiling, codec2's CMake builds its codebook generator for the host in a nested configure (an
    # ExternalProject). That one reads the environment, where the image sets CC and the flags for mingw, and would
    # produce a generate_codebook.exe that cannot run here. The outer build has its toolchain in the cache by now,
    # so drop the variables for make: the nested configure then finds the image's native gcc.
    # Only the library is built: `make install` would also build the forty-odd FreeDV command-line tools.
    env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u LDFLAGS make -j$(nproc) codec2

    # FFmpeg's configure asks for codec2/codec2.h (which includes the generated codec2/version.h) and -lcodec2.
    mkdir -p "$FFBUILD_DESTPREFIX"/lib "$FFBUILD_DESTPREFIX"/include/codec2
    cp "$(find . -name libcodec2.a | head -n1)" "$FFBUILD_DESTPREFIX"/lib/
    cp ../src/codec2.h "$(find . -name version.h -path '*codec2*' | head -n1)" "$FFBUILD_DESTPREFIX"/include/codec2/
}

ffbuild_configure() {
    echo --enable-libcodec2
}

ffbuild_unconfigure() {
    echo --disable-libcodec2
}
