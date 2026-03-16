# zon-version

Zig CLI tool for reading and bumping versions in `build.zig.zon` files.

No sed, no grep, no regex — proper `.zon` file handling that preserves formatting.

## Usage

```bash
# Read current version
zon-version get build.zig.zon
# → 0.1.0

# Set to specific version
zon-version set build.zig.zon 1.0.0

# Bump patch (0.1.0 → 0.1.1)
zon-version bump build.zig.zon patch

# Bump minor (0.1.0 → 0.2.0)
zon-version bump build.zig.zon minor

# Bump major (0.1.0 → 1.0.0)
zon-version bump build.zig.zon major
```

## Install

```bash
zig build -Doptimize=ReleaseFast
# Binary at zig-out/bin/zon-version
```

Or use as a GitHub Action (see svge-ai/.github workflows).

## How it works

Reads the `.zon` file as text, finds the `.version = "X.Y.Z"` field by pattern matching, and replaces only the version string — preserving all other content, formatting, and comments exactly as-is. No AST parsing, no serialization, no reformatting.

## License

MIT
