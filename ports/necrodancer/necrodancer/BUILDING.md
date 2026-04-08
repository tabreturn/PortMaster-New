# Building the NecroDancer Port

The port ships pre-built aarch64 Linux binaries. These must be built on a
**Debian Bullseye (11)** aarch64 system (or chroot) for glibc compatibility
with handheld Linux distributions (ArkOS, ROCKNIX, etc.).

Building on a newer distro (e.g., Fedora 40+) produces binaries that require
GLIBC_2.34+ which is not available on most handhelds.

## Prerequisites

### Bullseye chroot setup

If you don't have a native Bullseye aarch64 system, create a chroot:

```bash
sudo debootstrap --arch=arm64 bullseye /path/to/chroot
sudo chroot /path/to/chroot
```

### Build dependencies

Inside the chroot, install:

```bash
apt-get update
apt-get install build-essential cmake ninja-build clang git \
    libsdl2-dev libfreetype-dev libluajit-5.1-dev \
    libopenal-dev libvorbis-dev libogg-dev libflac-dev \
    libtheora-dev libcurl4-openssl-dev libzstd-dev \
    libx11-dev libxrandr-dev libgl-dev libglu1-mesa-dev \
    libegl-dev libgles-dev libudev-dev
```

## Source layout

The build happens in `standalone/` inside the darling repo. It produces:

| Output | Source |
|--------|--------|
| `mldr` (renamed to `machismo`) | `standalone/Makefile` |
| `libsystem_shim.so` | `standalone/Makefile` |
| `libc++.so.1`, `libc++abi.so.1` | `standalone/build-libcxx.sh` |
| `libbgfx-shared.so` | `standalone/build-bgfx.sh` |
| `libsfml-*.so.2.5` | `standalone/build-sfml.sh` |

## Build steps

All commands run inside the chroot, from the `standalone/` directory.

### 1. Makefile targets (mldr + libsystem_shim.so)

Bullseye's older glibc headers require `_GNU_SOURCE` for `mremap`,
`pthread_setname_np`, `MAP_FIXED_NOREPLACE`, etc. Add it to CFLAGS:

```bash
# In standalone/Makefile, line 3:
CFLAGS = -Wall -O2 -g -pthread -D_GNU_SOURCE
```

Then build:

```bash
make clean && make
```

This produces `mldr`, `wrapgen`, and `libsystem_shim.so`.

### 2. LuaJIT (optimized build)

Build a custom LuaJIT with CPU tuning and debug symbols (for perf visibility):

```bash
./scripts/build-luajit.sh
```

Output: `build-luajit/lib/libluajit-5.1.so.2`, `build-luajit/share/luajit-2.1/jit/*.lua`

The build uses `-O2 -mcpu=cortex-a35` by default. Override with `LUAJIT_MCPU=`
(empty) for generic aarch64. The binary is intentionally unstripped so perf
can show named LuaJIT internal functions.

### 3. Apple-ABI libc++ (LLVM 15)

Bullseye's system clang is too old for HEAD llvm-project. Use LLVM 15.0.7:

```bash
cd standalone/llvm-project
git checkout llvmorg-15.0.7
cd ..
```

Configure and build:

```bash
./build-libcxx.sh
cd build-libcxx && ninja cxx cxxabi && cd ..
```

Output: `build-libcxx/lib/libc++.so.1`, `build-libcxx/lib/libc++abi.so.1`

The critical flag is `-DLIBCXX_ABI_DEFINES="_LIBCPP_ABI_ALTERNATE_STRING_LAYOUT"`
which gives Apple's SSO string layout matching the game binary.

### 4. bgfx (GLES renderer)

Requires libc++ from step 3 (bgfx links against Apple-ABI libc++ so
std::string layout matches the game):

```bash
./build-bgfx.sh
```

Output: `build-bgfx/libbgfx-shared.so`

Note: The build script links `-lGL` but the renderer is configured for
GLES 3.1 only (`BGFX_CONFIG_RENDERER_OPENGLES=31`, `BGFX_CONFIG_RENDERER_OPENGL=0`).
The `libGL.so.1` dependency is dead weight and is removed via `patchelf` in the
packaging step below.

### 5. SFML 2.5.1

Requires libc++ from step 3:

```bash
./build-sfml.sh
```

Output: `build-sfml/lib/libsfml-{graphics,window,network,system}.so.2.5`

Only graphics, window, network, and system are used as native .so files.
Audio and system are loaded as **Mach-O dylibs** from the game's original
`.dylib` files to preserve the game's custom vtable layout.

## Packaging for the port

After building, copy binaries into `port/port/necrodancer/libs/` and fix
up ELF dependencies for GLES-only handhelds.

### Copy binaries

```bash
DEST=/path/to/port/port/necrodancer/libs

# Loader
cp standalone/mldr "$DEST/machismo"

# System shim
cp standalone/libsystem_shim.so "$DEST/"

# LuaJIT (optimized, unstripped)
cp standalone/build-luajit/lib/libluajit-5.1.so.2 "$DEST/"
cp -r standalone/build-luajit/share "$DEST/"

# Apple-ABI libc++
cp standalone/build-libcxx/lib/libc++.so.1 "$DEST/"
cp standalone/build-libcxx/lib/libc++abi.so.1 "$DEST/"

# bgfx
cp standalone/build-bgfx/libbgfx-shared.so "$DEST/"

# SFML — use soname versions, not .so.2.5.1
cp standalone/build-sfml/lib/libsfml-graphics.so.2.5 "$DEST/"
cp standalone/build-sfml/lib/libsfml-window.so.2.5 "$DEST/"
cp standalone/build-sfml/lib/libsfml-network.so.2.5 "$DEST/"
cp standalone/build-sfml/lib/libsfml-system.so.2.5 "$DEST/"
```

### Remove desktop GL dependencies

Target handhelds have GLES only (no `libGL.so.1` or `libGLU.so.1`).
bgfx already links `libEGL` + `libGLESv2` directly, and SFML's OpenGL
calls are not used (bgfx handles rendering via trampolines). Remove the
dead `libGL`/`libGLU` DT_NEEDED entries:

```bash
patchelf --remove-needed libGL.so.1 "$DEST/libbgfx-shared.so"
patchelf --remove-needed libGL.so.1 "$DEST/libsfml-graphics.so.2.5"
patchelf --remove-needed libGLU.so.1 "$DEST/libsfml-graphics.so.2.5"
patchelf --remove-needed libGL.so.1 "$DEST/libsfml-window.so.2.5"
patchelf --remove-needed libGLU.so.1 "$DEST/libsfml-window.so.2.5"
```

### Repackage zip

```bash
cd port/port
rm -f necrodancer.zip
zip -r necrodancer.zip necrodancer/ -x "necrodancer/gamedata/*" "necrodancer/userdata/*"
```

## Why Bullseye?

| Binary | Built on Fedora 42 | Built on Bullseye |
|--------|-------------------|-------------------|
| mldr/machismo | GLIBC_2.34 | GLIBC_2.17 |
| libbgfx-shared.so | GLIBC_2.38 | GLIBC_2.27 |
| libc++.so.1 | GLIBC_2.38 | GLIBC_2.17 |
| libsfml-graphics.so | GLIBC_2.38 | GLIBC_2.27 |

Most handheld distros ship glibc 2.28-2.31 (Bullseye = 2.31).

## System library sonames

The `dylib_map.conf` must use versioned sonames since handhelds don't have
`-dev` packages (no unversioned symlinks). These are the sonames found on
typical aarch64 handheld systems:

```
libfreetype.so.6      libvorbisfile.so.3
libopenal.so.1        libvorbis.so.0
libluajit-5.1.so.2    libvorbisenc.so.2
libz.so.1             libogg.so.0
libzstd.so.1          libtheoradec.so.1
libcurl.so.4          libtheora.so.0
libFLAC.so.8
```

## Git submodules

The build depends on these submodules in `standalone/`:

| Submodule | Pinned version | Purpose |
|-----------|---------------|---------|
| `llvm-project` | `llvmorg-15.0.7` (for Bullseye) | Apple-ABI libc++ source |
| `bgfx` | `36ec932f4` (API v118) | bgfx renderer source |
| `bimg` | `1955d8f` | bgfx image library |
| `bx` | `20efa22` | bgfx base library |
| `sfml` | `2f11710a` (2.5.1) | SFML source |

Initialize with:

```bash
git submodule update --init standalone/bgfx standalone/bimg standalone/bx standalone/sfml
git submodule update --init --depth 1 standalone/llvm-project
cd standalone/llvm-project && git checkout llvmorg-15.0.7
```
