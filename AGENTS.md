# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Build System

Eagle Mode uses a custom Perl-based build system (`make.pl`) instead of makefiles.

```bash
# Full build (defaults to gnu/gcc compiler)
perl make.pl build

# Build with clang
perl make.pl build compiler=clang

# Build specific sub-projects only
perl make.pl build projects=emCore,emMain

# Build with debug info, parallel on 4 CPUs
perl make.pl build debug=yes cpus=4

# Install to default /usr/local/eaglemode (or specify dir)
perl make.pl install
perl make.pl install dir=/opt/eaglemode menu=yes

# Run without installing (directly from source dir after build)
./eaglemode.sh

# Clean generated files (bin/, lib/, obj/)
perl make.pl clean

# Print all options
perl make.pl help
```

Each sub-project has a corresponding `makers/<name>.maker.pm` file. The `unicc` compiler wrapper (in `makers/unicc/`) handles auto-dependencies and parallel compilation. The bottom layer of compilation goes: `make.pl` → `<name>.maker.pm` → `unicc.pl` → gcc/clang.

## Running C++ API Examples

```bash
cd doc/examples/CppApiExamples
perl run-example.pl HelloWorldExample.cpp
```

This compiles and runs a standalone example in one step. Examples available: `HelloWorldExample.cpp`, `PaintExample.cpp`, `InputExample.cpp`, `SignalExample.cpp`, `SimpleAnimationExample.cpp`, `TreeExpansionExample.cpp`, `ToolkitExample.cpp`, `ModelExample.cpp`, and the full plugin in `PluginExample/`.

## Architecture

Eagle Mode is a **zoomable user interface** built as a monorepo of C++ sub-projects. Each sub-project compiles to either a shared library (`lib/`) or executable (`bin/`).

### Sub-project Structure

- **emCore** — The foundational library. All other sub-projects link against it. Headers in `include/emCore/`, source in `src/emCore/`.
- **emMain** — The main application executable (`bin/eaglemode`). Implements the virtual cosmos, bookmarks, and top-level window/control panel.
- **emX11 / emWnds** — Platform backends (X11 on Linux, Windows API on Windows). Eagle Mode selects the backend at runtime via `EM_GUI_LIB` env var.
- **emFileMan** — File manager plugin (directory browsing, file operations).
- **emText, emPng, emJpeg, emTiff, emPdf, emSvg**, etc. — File viewer plugins, one per file format.
- **emFractal, emMines, emClock, SilChess**, etc. — Application plugins shown in the virtual cosmos.
- **emTmpConv** — Shell-script-based conversion shim for file formats without native viewers.
- **font2em** — Utility to convert TTF/PCF fonts to TGA bitmaps used by emCore's font cache.

### Core API Concepts (emCore)

**Panels** (`emPanel`) are the fundamental UI element — rectangular, zoomable regions that form an infinite tree. The panel's coordinate system is always 1.0 units wide; height depends on the layout ratio. Child panels are always clipped by their parent.

- `AutoExpand()` / `AutoShrink()` — Override to lazily create/destroy child panels as the user zooms in/out. This is the primary mechanism for handling large or infinite panel trees.
- `LayoutChildren()` — Override to position children using `child->Layout(x, y, w, h, canvasColor)`.
- `Paint(painter, canvasColor)` — Override to draw. Canvas color optimization: pass it through to painter calls when available.
- `IsOpaque()` — Override to return `true` when the panel covers its full area; lets the framework skip painting its parent.
- `Input(event, state, mx, my)` — Override to handle keyboard/mouse. Always call the base class.

**Engines** (`emEngine`) are the base class for all high-level objects. `Cycle()` is called up to ~100 times/second when the engine is awake. Return `false` from `Cycle()` to go idle; return `true` to keep polling. Wake an engine with `WakeUp()` or via signals.

**Signals** (`emSignal`) — An engine subscribes with `AddWakeUpSignal(signal)` and checks delivery in `Cycle()` with `IsSignaled(signal)`. Senders call `Signal(mySignal)`. Decoupled: senders need not know their receivers. `emTimer` generates periodic signals.

**Models and Contexts** (`emModel`, `emContext`, `emRef`):

- Data lives in `emModel` subclasses, not in panels (panels come and go with zoom).
- Models are created/found via a static `Acquire(context, name)` method and stored in `emRef<T>` smart pointers.
- `emRootContext` — singleton "global" context; for data shared across all windows.
- `emView` / `emWindow` — per-window contexts; for per-window state.
- Models auto-delete when the last `emRef` drops; call `SetMinCommonLifetime(seconds)` for caching.
- `emFileModel` / `emRecFileModel` — specialized base classes for file-backed models; paired with `emFilePanel` on the view side.

### Plugin System (emFpPlugin)

File panel plugins map file extensions to viewer/editor panels:

1. A shared library in `lib/` exports a C function with signature matching `emFpPluginFunc`.
2. A `.emFpPlugin` config file in `etc/emCore/FpPlugins/` (or `etcw/` on Windows, or `~/.eaglemode/emCore/FpPlugins/` for user overrides) declares the library name, function, file types, and priority.
3. Optionally, a `.emVcItem` file in `etc/emMain/VcItems/` places a plugin in the virtual cosmos.

Priority conventions: `1.0` = specialized viewer, `0.5` = temporary conversion, `0.1` = plain text, `0.0` = hex dump.

Adding a new plugin requires only adding new files — no modification of existing files needed.

### Configuration Directories

- `etc/` — UNIX/Linux runtime configuration (FpPlugins, VcItems, VcItemFiles).
- `etcw/` — Windows runtime configuration (identical structure).
- `res/` — Read-only resources (images, fonts in TGA format, icons).
- Font bitmaps: `res/emCore/font/` — TGA files named `<first>-<last>_<W>x<H>_<desc>.tga` covering Unicode ranges. Extend with `font2em`.

### Key Header Files

- `include/emCore/emPanel.h` — Panel base class with full API comments.
- `include/emCore/emEngine.h` — Engine/signal/scheduler base.
- `include/emCore/emModel.h`, `emContext.h`, `emRef.h` — Data model layer.
- `include/emCore/emPainter.h` — Drawing API (rectangles, ellipses, polygons, text, images).
- `include/emCore/emFpPlugin.h` — Plugin function signature and configuration structure.
- `include/emCore/emRec.h` — Serializable record types used for file formats.

### Record Format (emRec)

Files like `.emVcItem` and `.emFpPlugin` use Eagle Mode's own text format, opened with `#%rec:<TypeName>%#`. `emStructRec`, `emArrayRec`, `emColorRec`, etc. are the C++ classes for defining these schemas.

## Dependencies (Linux)

Essential: `perl`, `gcc`/`g++` (≥ 4.9), `libx11-dev`  
Optional (per plugin): `libjpeg-dev`, `libpng-dev`, `libtiff-dev`, `libwebp-dev`, `libvlc-dev` (VLC 3.x), `librsvg2-dev`, `libpoppler-glib-dev`, `libgtk-3-dev`, `libfreetype6-dev`
