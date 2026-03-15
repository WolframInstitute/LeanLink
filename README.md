# LeanLink

Wolfram Language paclet for native integration with the [Lean 4](https://lean-lang.org/) proof assistant.

## Features

- **Native LibraryLink bridge** -- embeds the Lean runtime directly in Wolfram Language via a C shim, no subprocess overhead
- **Environment loading** -- loads Lean `.olean` environments and queries constants, theorems, and types
- **WXF serialization** -- Lean expressions are serialized to WXF and deserialized as symbolic Wolfram expressions (`LeanApp`, `LeanConst`, `LeanForall`, etc.)
- **Theorem listing** -- enumerate and filter constants in a Lean environment

## Quick Start

```wolfram
<< LeanLink`

(* Load a Lean environment *)
env = LeanLoadEnv["OneSidedTM.PlusOne",
  "/path/to/proofs/.lake/build/lib:/path/to/lean/lib/lean"];

(* Get the type of a theorem *)
LeanGetType[env, "OneSidedTM.rule445_computesSucc"]
(* LeanApp[LeanConst["OneSidedTM.ComputesSucc", {}], LeanConst["OneSidedTM.rule445", {}]] *)
```

## Building

### Prerequisites
- [Lean 4](https://leanprover.github.io/lean4/doc/setup.html) (via elan)
- [Wolfram Language](https://www.wolfram.com/language/) 15.0+
- C compiler (clang/gcc)

### Build steps

```bash
cd Native

# Build Lean library
lake build

# Build C shim
LEAN_HOME=$(elan which lean | sed 's|/bin/lean||')
WL_INCLUDE="/Applications/Wolfram 15.0.app/Contents/SystemFiles/IncludeFiles/C"

cc -shared -O2 \
  -I"$LEAN_HOME/include" -I"$WL_INCLUDE" \
  -L"$LEAN_HOME/lib/lean" -lleanshared \
  -rpath "$LEAN_HOME/lib/lean" \
  -o .lake/build/lib/libLeanLinkShim.dylib \
  .lake/build/ir/LeanLink.c \
  .lake/build/ir/LeanLink/WXF.c \
  .lake/build/ir/LeanLink/EnvStore.c \
  shim/leanlink_shim.c
```

## Architecture

```
LeanLink/
├── Kernel/           # Wolfram Language package (.wl)
├── Native/
│   ├── lib/          # Lean 4 source
│   │   └── LeanLink/
│   │       ├── EnvStore.lean   # Environment loading & management
│   │       └── WXF.lean        # WXF binary serialization
│   └── shim/
│       └── leanlink_shim.c     # LibraryLink C bridge
└── PacletInfo.wl
```

## License

MIT
