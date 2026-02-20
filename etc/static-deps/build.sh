#!/usr/bin/env bash
#
# Build static (.a) libraries for x264 and nlopt using zig cc for cross-compilation.
#
# System dependencies:
#   - zig (>= 0.11): C/C++ cross-compiler. Install from https://ziglang.org/download/
#   - nasm (>= 2.14): x86 assembler for x264 SIMD. Install via: apt install nasm
#   - cmake (>= 3.10): build system for nlopt. Install via: apt install cmake
#   - git: to clone sources
#
# Usage:
#   ./build.sh                    # build all targets
#   ./build.sh linux-amd64        # build one target
#   ./build.sh linux-arm64 linux-amd64
#
# Output goes to etc/static-deps/out/<target>/{lib,include}/
#
# The output directories contain only .a files (no .so), so the linker will
# use them for static linking without needing -Bstatic. Just point CGO_LDFLAGS
# at the output lib/ directory:
#
#   PKG_CONFIG_PATH=.../out/linux-amd64/lib/pkgconfig \
#   CGO_LDFLAGS="-L.../out/linux-amd64/lib" \
#   go build -ldflags "-extldflags '-static-libgcc -static-libstdc++'" \
#     ./web/cmd/server
#
# CGO_LDFLAGS is required because go does not forward -L paths from pkg-config
# to the external linker. PKG_CONFIG_PATH provides headers and -l flags.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$SCRIPT_DIR/out"

# Pinned versions
X264_REPO="https://code.videolan.org/videolan/x264.git"
X264_BRANCH="stable"

NLOPT_REPO="https://github.com/stevengj/nlopt.git"
NLOPT_TAG="v2.7.0"

# Target → zig target triple mapping
declare -A ZIG_TARGET=(
    [linux-amd64]="x86_64-linux-gnu.2.17"
    [linux-arm64]="aarch64-linux-gnu.2.17"
    [windows-amd64]="x86_64-windows-gnu"
    [darwin-arm64]="aarch64-macos"
)

# Targets that need nasm for x264 SIMD assembly
declare -A NEEDS_NASM=(
    [linux-amd64]=1
    [windows-amd64]=1
)

ALL_TARGETS=(linux-amd64 linux-arm64 windows-amd64 darwin-arm64)

# ── helpers ──────────────────────────────────────────────────────────────────

log() { echo "==> $*" >&2; }

make_zigcc_wrapper() {
    local target="$1" wrapper="$2"
    cat > "$wrapper" <<EOF
#!/bin/sh
exec zig cc -target $target "\$@"
EOF
    chmod +x "$wrapper"
}

make_zigcxx_wrapper() {
    local target="$1" wrapper="$2"
    cat > "$wrapper" <<EOF
#!/bin/sh
exec zig c++ -target $target "\$@"
EOF
    chmod +x "$wrapper"
}

make_zigar_wrapper() {
    local wrapper="$1"
    cat > "$wrapper" <<'EOF'
#!/bin/sh
exec zig ar "$@"
EOF
    chmod +x "$wrapper"
}

make_zigranlib_wrapper() {
    local wrapper="$1"
    cat > "$wrapper" <<'EOF'
#!/bin/sh
exec zig ranlib "$@"
EOF
    chmod +x "$wrapper"
}

# ── source checkout ──────────────────────────────────────────────────────────

checkout_sources() {
    mkdir -p "$SRC_DIR"

    if [ ! -d "$SRC_DIR/x264" ]; then
        log "Cloning x264 ($X264_BRANCH)"
        git clone --depth 1 -b "$X264_BRANCH" "$X264_REPO" "$SRC_DIR/x264"
    else
        log "Using existing x264 source"
    fi

    if [ ! -d "$SRC_DIR/nlopt" ]; then
        log "Cloning nlopt ($NLOPT_TAG)"
        git clone --depth 1 -b "$NLOPT_TAG" "$NLOPT_REPO" "$SRC_DIR/nlopt"
    else
        log "Using existing nlopt source"
    fi
}

# ── x264 ─────────────────────────────────────────────────────────────────────

build_x264() {
    local target="$1"
    local zig_target="${ZIG_TARGET[$target]}"
    local prefix="$OUT_DIR/$target"
    local builddir="$SRC_DIR/x264/build-$target"
    local wrapdir="$builddir/wrappers"

    if [ -f "$prefix/lib/libx264.a" ]; then
        log "x264/$target: already built, skipping (rm $prefix/lib/libx264.a to rebuild)"
        return
    fi

    log "x264/$target: building"

    rm -rf "$builddir"
    mkdir -p "$builddir" "$wrapdir" "$prefix"

    make_zigcc_wrapper "$zig_target" "$wrapdir/zigcc"
    make_zigar_wrapper "$wrapdir/zigar"
    make_zigranlib_wrapper "$wrapdir/zigranlib"

    local configure_flags=(
        --prefix="$prefix"
        --enable-static
        --disable-shared
        --enable-pic
        --disable-cli
        --disable-avs
        --disable-swscale
        --disable-lavf
        --disable-ffms
        --disable-gpac
        --disable-lsmash
    )

    # Configure cross-compilation host
    case "$target" in
        linux-amd64)   configure_flags+=(--host=x86_64-linux) ;;
        linux-arm64)   configure_flags+=(--host=aarch64-linux) ;;
        windows-amd64) configure_flags+=(--host=x86_64-w64-mingw32) ;;
        darwin-arm64)  configure_flags+=(--host=aarch64-apple-darwin) ;;
    esac

    # Disable asm on targets where nasm isn't used or available
    if [ -z "${NEEDS_NASM[$target]:-}" ]; then
        case "$target" in
            darwin-arm64|linux-arm64)
                # ARM uses .S files compiled through CC — asm works without nasm
                ;;
            *)
                configure_flags+=(--disable-asm)
                ;;
        esac
    fi

    cd "$SRC_DIR/x264"

    CC="$wrapdir/zigcc" \
    AR="$wrapdir/zigar" \
    RANLIB="$wrapdir/zigranlib" \
    ./configure "${configure_flags[@]}"

    make -j"$(nproc)" DESTDIR= clean || true
    make -j"$(nproc)"
    make install

    cd "$SCRIPT_DIR"
    rm -rf "$builddir"

    log "x264/$target: installed to $prefix"
}

# ── nlopt ────────────────────────────────────────────────────────────────────

build_nlopt() {
    local target="$1"
    local zig_target="${ZIG_TARGET[$target]}"
    local prefix="$OUT_DIR/$target"
    local builddir="$SRC_DIR/nlopt/build-$target"
    local wrapdir="$builddir/wrappers"

    if [ -f "$prefix/lib/libnlopt.a" ]; then
        log "nlopt/$target: already built, skipping (rm $prefix/lib/libnlopt.a to rebuild)"
        return
    fi

    log "nlopt/$target: building"

    rm -rf "$builddir"
    mkdir -p "$builddir" "$wrapdir" "$prefix"

    make_zigcc_wrapper "$zig_target" "$wrapdir/zigcc"
    make_zigcxx_wrapper "$zig_target" "$wrapdir/zigcxx"
    make_zigar_wrapper "$wrapdir/zigar"
    make_zigranlib_wrapper "$wrapdir/zigranlib"

    # Determine cmake system name
    local cmake_system
    case "$target" in
        linux-*)   cmake_system="Linux" ;;
        darwin-*)  cmake_system="Darwin" ;;
        windows-*) cmake_system="Windows" ;;
    esac

    local cmake_arch
    case "$target" in
        *-amd64) cmake_arch="x86_64" ;;
        *-arm64) cmake_arch="aarch64" ;;
    esac

    cd "$builddir"

    cmake "$SRC_DIR/nlopt" \
        -DCMAKE_C_COMPILER="$wrapdir/zigcc" \
        -DCMAKE_CXX_COMPILER="$wrapdir/zigcxx" \
        -DCMAKE_AR="$wrapdir/zigar" \
        -DCMAKE_RANLIB="$wrapdir/zigranlib" \
        -DCMAKE_SYSTEM_NAME="$cmake_system" \
        -DCMAKE_SYSTEM_PROCESSOR="$cmake_arch" \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DNLOPT_CXX=OFF \
        -DNLOPT_PYTHON=OFF \
        -DNLOPT_OCTAVE=OFF \
        -DNLOPT_MATLAB=OFF \
        -DNLOPT_GUILE=OFF \
        -DNLOPT_SWIG=OFF \
        -DNLOPT_TESTS=OFF

    make -j"$(nproc)"
    make install

    cd "$SCRIPT_DIR"
    rm -rf "$builddir"

    log "nlopt/$target: installed to $prefix"
}

# ── main ─────────────────────────────────────────────────────────────────────

check_deps() {
    local missing=()
    command -v zig   >/dev/null || missing+=(zig)
    command -v cmake >/dev/null || missing+=(cmake)
    command -v git   >/dev/null || missing+=(git)

    # nasm only required if building x86 targets
    for t in "$@"; do
        if [ -n "${NEEDS_NASM[$t]:-}" ]; then
            command -v nasm >/dev/null || missing+=(nasm)
            break
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing required tools: ${missing[*]}" >&2
        echo "Install them and retry." >&2
        exit 1
    fi
}

main() {
    local targets=("${@:-${ALL_TARGETS[@]}}")

    # Validate targets
    for t in "${targets[@]}"; do
        if [ -z "${ZIG_TARGET[$t]:-}" ]; then
            echo "Unknown target: $t" >&2
            echo "Valid targets: ${ALL_TARGETS[*]}" >&2
            exit 1
        fi
    done

    check_deps "${targets[@]}"
    checkout_sources

    for t in "${targets[@]}"; do
        build_x264 "$t"
        build_nlopt "$t"
        log "$t: done → $OUT_DIR/$t/{lib,include}/"
    done

    echo ""
    echo "Static libraries built successfully."
    echo ""
    echo "To use with CGO, set:"
    echo "  export CGO_LDFLAGS=\"-L$OUT_DIR/<target>/lib\""
    echo "  export CGO_CFLAGS=\"-I$OUT_DIR/<target>/include\""
    echo ""
    echo "Or use the Makefile integration (see Makefile static-deps target)."
}

main "$@"
