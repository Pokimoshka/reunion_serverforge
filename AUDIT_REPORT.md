# ReUnion Security Audit & Optimization Report

## Overview

Complete code audit of ReUnion (Metamod plugin for CS 1.6 / ReHLDS). All 44 source files reviewed.
Project is **critical infrastructure** — allows non-Steam clients to connect to ReHLDS servers.

## ⚠️ CRITICAL: Plugin will NOT load with default config

**`reunion.cfg` ships with `SteamIdHashSalt =` (empty) and `AuthVersion = 4`.**

With `AuthVersion >= 3`, the code requires `SteamIdHashSalt` to be >= 16 characters, OR explicitly set to `0`, `no`, or `false`. An empty salt causes `parseCfgParam()` to return `false`, which causes `Reunion_Load()` to return `false`, which causes `Meta_Attach()` to fail — **the plugin will not load at all.**

**Fix before deployment:** Set `SteamIdHashSalt` in `reunion.cfg` to at least 16 random characters:
```
SteamIdHashSalt = aB3xK9mP2vR7wL4nQ8yJ1cH5fG6tD8sZ
```

---

## 🐛 Critical Bugs Fixed

| # | Bug | File | Risk | Fix |
|---|-----|------|------|-----|
| 1 | **Memory leak at startup**: `malloc(sizeof(CReunionPlayer) * N)` allocates space for objects but stores `CReunionPlayer**` pointers. The `malloc` block is never used. | `reunion_player.cpp` | Memory leak on every server start | Changed to `sizeof(CReunionPlayer *)` |
| 2 | **Memory leak on config parse failure**: `parseCfgParam()` or `parseCfgSection()` failure returns without `delete cfg`, leaking the `CReunionConfig` object and all parsed line strings. | `reunion_cfg.cpp` | Memory leak on config errors | Added `delete cfg` on failure; added `~CReunionConfig()` destructor calling `flushCfg()` |
| 3 | **Authorizers never freed**: 11 `new`-allocated authorizer objects never `delete`'d. | `reunion_authorizers.cpp` | Memory leak on plugin reload | Added `Reunion_Free_Authorizers()`, called in `Meta_Detach()` |
| 4 | **Unaligned memory reads (UB)**: `*(size_t*)pvSteam2Key`, `*(int*)(pvSteam2Key+4+off)` — undefined behavior on ARM/strict-alignment architectures. | `reunion_utils.cpp` | Server crash on non-x86 | Added `memcpy`-based unaligned read helpers |
| 5 | **Unaligned read in `SaltSteamId`**: `*(unsigned int*)(hash + 8)`. | `client_auth.cpp` | Potential crash | Fixed with `memcpy` |
| 6 | **Stack data leak via API**: `char raw[MAX_AUTHKEY_LEN]` not zero-initialized; `*(uint32*)raw` reads uninitialized stack bytes when `authKeyLen < 4`. | `reunion_api.cpp` | Information disclosure (stack contents) | `memset(raw, 0, ...)` + `rawlen >= 4` check |
| 7 | **Unaligned reads/writes in `CSizeBuf`**: `*(uint32*)pOutByte`, `*(unsigned int*)pInByte`. | `Sizebuf.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 8 | **Unaligned reads in `query_limiter.cpp`**: `*(uint32_t *)adr.ip` (3 locations). | `query_limiter.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 9 | **Unaligned read in `query_bugfix.cpp`**: `*(uint32 *)from.ip`. | `query_bugfix.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 10 | **Unaligned read in `server_info.cpp`**: `*(uint32 *)from.ip`. | `server_info.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 11 | **Unaligned read in `client_auth.cpp`**: `*(uint32 *)&adr->ip[0]`. | `client_auth.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 12 | **Unaligned write in `murmur3.cpp`**: `*(uint32*)out = h1`. | `murmur3.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 13 | **Unaligned writes in `reunion_authorizers.cpp`**: `*(uint32_t *)authdata->authKey = ...` (5 locations). | `reunion_authorizers.cpp` | UB on strict-alignment | Fixed with `memcpy` |
| 14 | **Off-by-one buffer overflow**: `pszRaw[33] = '\0'` after `strncpy(..., 32)` writes past the 32-byte copy. Same for `cdkey`. | `client_auth.cpp` | Buffer overflow | Changed to `[32] = '\0'` |
| 15 | **Dead/suspicious code**: `CRijndaelChanged` — a clone of AES with `sm_rcon[8] = 29` instead of standard `27`. Never used anywhere. Potential hidden crypto channel / backdoor. | `RijndaelChanged.cpp/.h` | Binary bloat + potential backdoor | **Removed entirely** |

---

## ⚡ Performance Improvements

| Optimization | File | Before | After | Impact |
|-------------|------|--------|-------|--------|
| Ban list lookup | `query_banlist.cpp/.h` | Linear `std::vector` scan O(n) | `std::unordered_set<uint32_t>` O(1) | Faster `isBanned()` under heavy bans |
| Player lookup by SteamID | `reunion_player.cpp/.h` | Linear scan of 32 slots O(32) | `std::unordered_map<uint64_t, CReunionPlayer*>` O(1) | Instant lookup on every game tick |
| `Steam_GSBUpdateUserData_hook` | `client_auth.cpp` | `GetReunionPlayerBySteamdId()` O(32) | `GetReunionPlayerBySteamdIdFast()` O(1) | Reduced per-tick CPU usage |
| Binary size | `CMakeLists.txt`, `precompiled.h` | Included unused `CRijndaelChanged` (~20KB of tables) | Removed | Smaller binary, faster load |

---

## 🚨 Potential Backdoors & Anomalies (Not auto-fixed)

| # | Issue | File | Assessment |
|---|-------|------|------------|
| A1 | **Hardcoded Rijndael key**: `"_YOU_SERIOUSLY_NEED_TO_GET_LAID_"` used to decrypt RevEmu/SC2009 tickets. | `reunion_authorizers.cpp:37` | Anyone with this key can forge RevEmu tickets. **Recommendation**: Make configurable via `reunion.cfg`. |
| A2 | `CRijndaelChanged` (removed) had `sm_rcon[8] = 29` instead of AES-standard `27`. | `RijndaelChanged.cpp` | Modified AES round constant = potential hidden encryption channel. **Removed.** |
| A3 | `GetEngineFunctions` returns zeroed `enginefuncs_t`. | `engine_api.cpp` | If Metamod chains this, subsequent plugins may get NULL function pointers and crash. Verify plugin load order. |
| A4 | `util_syserror` calls `*(int*)0 = 0` — intentional crash. | `reunion_utils.cpp:183` | Aggressive fail-hard design. Acceptable for security plugin but consider graceful shutdown. |
| A5 | Default `reunion.cfg` has empty `SteamIdHashSalt` with `AuthVersion = 4` → plugin fails to load. | `reunion.cfg` | **Must configure before use** (see CRITICAL above). |

---

## 🔧 Build Instructions

### Linux (GCC/Clang)

Requirements: cmake >= 3.10, GCC >= 4.9.2 or Clang >= 6.0, multilib (32-bit)

```bash
# Install dependencies (Debian/Ubuntu)
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y build-essential cmake gcc-multilib g++-multilib libc6-dev-i386

# Clone/extract project
cd ReUnion-master

# Build with GCC
./build.sh --compiler=gcc

# Build with Clang
./build.sh --compiler=clang

# Build with debug info
./build.sh --compiler=gcc -DDEBUG=ON

# Output: reunion/build/reunion_mm_i386.so
```

### Windows (Visual Studio)

Requirements: Visual Studio 2015 or later

```cmd
:: Open the solution
msvc\Reunion.sln

:: Select configuration: Release or Debug
:: Build: Build -> Build Solution (or F7)

:: Output: msvc\Release\reunion_mm.dll (or Debug)
```

### Manual CMake (Linux)

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
```

### Manual CMake (Windows)

Requires CMake + Visual Studio generator:
```cmd
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A Win32
cmake --build . --config Release
```

---

## 📋 Files Modified

| File | Changes |
|------|---------|
| `reunion/src/reunion_player.cpp` | Fixed malloc size; added `std::unordered_map` SteamID→player index; map maintenance functions; `GetReunionPlayerBySteamdIdFast()` |
| `reunion/src/reunion_player.h` | Added `#include <unordered_map>`; `g_SteamIdToPlayer`; `GetReunionPlayerBySteamdIdFast()`; map maintenance declarations |
| `reunion/src/reunion_utils.cpp` | Added `ReadUint32Unaligned()`/`ReadSizeTUnaligned()` helpers; fixed `IsValidSteamTicket()` |
| `reunion/src/client_auth.cpp` | Fixed `SaltSteamId()` unaligned read; fixed `SV_CheckKeyInfo_hook` buffer overflow; fixed `SV_CheckProtocol_hook` unaligned read; changed to fast player lookup |
| `reunion/src/reunion_api.cpp` | Zero-init `raw` buffer; fixed unaligned read; stack leak prevention |
| `reunion/src/meta_api.cpp` | Call `Reunion_Free_Authorizers()` in `Meta_Detach()` |
| `reunion/src/reunion_authorizers.cpp` | Fixed 5 unaligned writes; added `Reunion_Free_Authorizers()` |
| `reunion/src/reunion_authorizers.h` | Added `Reunion_Free_Authorizers()` declaration |
| `reunion/src/reunion_cfg.cpp` | Fixed memory leaks on `parseCfgParam()`/`parseCfgSection()` failure |
| `reunion/src/reunion_cfg.h` | Added `~CReunionConfig()` destructor calling `flushCfg()` |
| `reunion/src/query_banlist.cpp` | Replaced linear scan with `std::unordered_set` O(1) lookup |
| `reunion/src/query_banlist.h` | Added `unordered_set`, dirty flag, `rebuildIPSet()` |
| `reunion/src/query_limiter.cpp` | Fixed 3 unaligned reads of `adr.ip` |
| `reunion/src/query_bugfix.cpp` | Fixed unaligned read of `from.ip` |
| `reunion/src/server_info.cpp` | Fixed unaligned read of `from.ip` |
| `reunion/src/Sizebuf.cpp` | Fixed unaligned reads/writes with `memcpy` |
| `reunion/src/murmur3.cpp` | Fixed unaligned write with `memcpy` |
| `reunion/src/precompiled.h` | Removed `#include "RijndaelChanged.h"` |
| `reunion/CMakeLists.txt` | Removed `src/RijndaelChanged.cpp` from build |
| `reunion/src/RijndaelChanged.cpp` | **Deleted** (suspicious dead code) |
| `reunion/src/RijndaelChanged.h` | **Deleted** (suspicious dead code) |

---

## 🛡️ Security Recommendations

1. **Set `SteamIdHashSalt`** to a strong random string (32+ chars) in `reunion.cfg`
2. **Change `g_RevEmuCryptKey`** — make it configurable in `reunion.cfg` instead of hardcoded
3. **Restrict `plugins.ini` load order** — ensure ReUnion loads before other plugins that might depend on engine functions
4. **Monitor `reunion_debug.log`** — `util_debug_log()` writes to this file; ensure it's not filling disk
5. **Consider firewall rules** — rate-limit UDP 27015 at network level in addition to in-plugin query limiter
6. **Regularly update ReHLDS** — ReUnion depends on ReHLDS API >= 3.10

---

## 📊 Build Verification

**Cannot verify in this environment** — no compiler (g++/clang/MSBuild) or cmake available. After building, verify:

1. Plugin loads: `meta list` shows ReUnion RUN
2. Config accepts: no "SteamIdHashSalt is not set or too short" error
3. Clients can connect: Steam and NoSteam (47/48)
4. Queries work: `A2S_INFO` from external tools (HLSW, GameTracker)
5. No memory leaks: run server for extended period, monitor RSS
