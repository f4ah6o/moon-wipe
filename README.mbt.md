# moon-wipe

Recursively find and optionally wipe MoonBit build directories.

`moon clean` only cleans the module you are standing in. `moon-wipe` walks a
whole tree, reports what it found and how much space it occupies, and deletes
it only when you ask.

## Install

### moon-binstall

```bash
moon binstall f4ah6o/moon-wipe
```

Prebuilt binaries are published to GitHub Releases for `linux-x86_64`,
`linux-aarch64` and `darwin-aarch64`. Linux binaries need glibc 2.34 or
newer; `moon-binstall.json` declares that floor, so an older host stops with
a build-from-source hint instead of a loader error.

The Mooncakes coordinate resolves the same assets through
`moon-binstall.json`:

```bash
moon binstall f4ah6o/moon-wipe/cmd/moon-wipe
```

### From source

```bash
moon install --path ./cmd/moon-wipe
# => ~/.moon/bin/moon-wipe
```

The installed binary is named after the main package directory, which is why
the package lives in `cmd/moon-wipe` rather than `cmd/main`.

## Usage

```bash
moon-wipe [TARGET] [OPTIONS]
```

`TARGET` is one of:

| Target | Looks for | Marker |
|---|---|---|
| `moon` (default) | `_build` | `.moon_db` |
| `mooncakes` | `.mooncakes` | `.moon-lock` |
| `all` | both of the above | |
| `cache` | `$MOON_HOME/cache`, `$MOON_HOME/registry` | |

A directory is only reported when it carries the marker, so a directory that
merely shares the name is left alone.

The default is a dry run:

```console
$ moon-wipe
moon-wipe 0.1.0
Searching for MoonBit build directories in /home/you/code

  /home/you/code/a/_build   1.2 GiB  1,234 files
  /home/you/code/b/_build  340.5 MiB    567 files

Found 2 directories, 1.5 GiB, 1,801 files
Dry run: re-run with -w to delete
```

Add `-w` to delete:

```console
$ moon-wipe -w
...
Wiped 2 directories, freed 1.5 GiB
```

### Options

| Flag | Meaning |
|---|---|
| `-w`, `--wipe` | Delete what was found |
| `-i`, `--ignore <PATH>` | Skip this path; repeatable |
| `--root <PATH>` | Start searching here (default: current directory) |
| `--min-size <SIZE>` | Only report directories at least this large |
| `--older-than <DAYS>` | Only report directories untouched for this many days |
| `--json` | Emit machine-readable JSON |
| `-h`, `--help` | Print help |
| `-V`, `--version` | Print the version |

Sizes accept binary units and decimals: `100`, `512K`, `1.5G`, `2GiB`.

## Why the walk prunes

A `_build` directory contains a copy of the dependency sources:

```text
_build/native/debug/build/.mooncakes/...
```

So the walk never descends into a directory whose name is a MoonBit artifact,
whatever the current target is looking for. Without that rule, `moon-wipe
mooncakes` would report the same dependency tree once per build profile.

## Library

The scanner is usable on its own.

```mbt check
///|
test {
  let options = @moon-wipe.Options::new()
  inspect(options.target.name(), content="moon")
  inspect(options.wipe, content="false")
}
```

```mbt check
///|
test {
  inspect(@moon-wipe.format_bytes(1536), content="1.5 KiB")
  inspect(@moon-wipe.group_digits(1234567), content="1,234,567")
}
```

```mbt check
///|
test {
  debug_inspect(
    @moon-wipe.cache_dirs_from("/home/u/.moon", None, None),
    content="[\"/home/u/.moon/cache\", \"/home/u/.moon/registry\"]",
  )
}
```

## Development

```bash
moon check
moon test
moon fmt
```

### Releasing

Bump `version` in `moon.mod` and push to `main`. The release workflow reads
the version with `scripts/version.mbtx`, compares it against the previous
`moon.mod`, and only builds when the version actually moved. It then tags
`v<version>` and attaches `moon-wipe-<target>` for each target.

Pushing a `v<version>` tag by hand works too, as long as the tag matches
`moon.mod`; a mismatch fails the run before anything is built.
