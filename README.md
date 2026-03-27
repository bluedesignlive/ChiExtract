# ChiExtract

> *Less, but better.* — Dieter Rams

A simple, timeless archive extraction tool designed with Material 3 Expressive principles.

## Features

- **One action**: Drop archive → Extract
- **Smart defaults**: Extracts to folder named after archive
- **Format support**: ZIP, TAR, TAR.GZ, TAR.BZ2, TAR.XZ, 7Z, GZ
- **Material 3 Expressive**: Modern, accessible, beautiful
- **Dark mode**: Easy on the eyes

## Build Requirements

- Qt 6.5+
- CMake 3.16+
- C++17 compiler

## Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel
```

## Run

```bash
./build/ChiExtract
```

## Design Philosophy

ChiExtract follows Dieter Rams' 10 principles:

1. **Innovative** — Smart destination prediction
2. **Useful** — Every feature serves extraction
3. **Aesthetic** — Material 3 Expressive design
4. **Understandable** — Self-explanatory UI
5. **Unobtrusive** — Stays out of your way
6. **Honest** — Accurate progress, clear errors
7. **Long-lasting** — Timeless design
8. **Thorough** — Every pixel intentional
9. **Environmentally friendly** — Minimal resources
10. **As little design as possible** — Remove until it breaks

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open file browser |
| `Escape` | Cancel / Clear |

## License

MIT
