///|
/// Parse `args` and require that they describe a run.
fn options_of(args : Array[String]) -> @moon-wipe.Options raise {
  guard @moon-wipe.parse_args(args) is @moon-wipe.Command::Run(options) else {
    fail("expected a run command")
  }
  options
}

///|
test "defaults search for _build under the current directory" {
  let options = options_of([])
  inspect(options.root, content=".")
  debug_inspect(options.target, content="Moon")
  inspect(options.wipe, content="false")
  inspect(options.ignores.length(), content="0")
  inspect(options.min_size, content="0")
  inspect(options.json, content="false")
  debug_inspect(options.older_than_days, content="None")
}

///|
test "wipe and json flags" {
  let options = options_of(["-w", "--json"])
  inspect(options.wipe, content="true")
  inspect(options.json, content="true")
}

///|
test "long wipe flag" {
  inspect(options_of(["--wipe"]).wipe, content="true")
}

///|
test "target is a positional argument" {
  debug_inspect(options_of(["mooncakes"]).target, content="Mooncakes")
  debug_inspect(options_of(["all"]).target, content="All")
  debug_inspect(options_of(["cache"]).target, content="Cache")
}

///|
test "flags may follow the target" {
  let options = options_of(["moon", "-w"])
  debug_inspect(options.target, content="Moon")
  inspect(options.wipe, content="true")
}

///|
test "root accepts a separate value or an inline one" {
  inspect(options_of(["--root", "/tmp/a"]).root, content="/tmp/a")
  inspect(options_of(["--root=/tmp/b"]).root, content="/tmp/b")
}

///|
test "ignore is repeatable and accepts an inline value" {
  let options = options_of(["-i", "/a", "--ignore", "/b", "--ignore=/c"])
  inspect(options.ignores.length(), content="3")
  inspect(options.ignores[0], content="/a")
  inspect(options.ignores[1], content="/b")
  inspect(options.ignores[2], content="/c")
}

///|
test "min-size accepts a separate value or an inline one" {
  inspect(options_of(["--min-size", "100M"]).min_size, content="104857600")
  inspect(options_of(["--min-size=2G"]).min_size, content="2147483648")
}

///|
test "older-than accepts a separate value or an inline one" {
  debug_inspect(
    options_of(["--older-than", "30"]).older_than_days,
    content="Some(30)",
  )
  debug_inspect(
    options_of(["--older-than=7"]).older_than_days,
    content="Some(7)",
  )
}

///|
/// Name the command variant without requiring `Debug` on `Command`.
fn kind_of(command : @moon-wipe.Command) -> String {
  match command {
    @moon-wipe.Command::Help => "help"
    @moon-wipe.Command::Version => "version"
    @moon-wipe.Command::Run(_) => "run"
  }
}

///|
test "help and version short-circuit" {
  inspect(kind_of(@moon-wipe.parse_args(["--help"])), content="help")
  inspect(kind_of(@moon-wipe.parse_args(["-h"])), content="help")
  inspect(kind_of(@moon-wipe.parse_args(["--version"])), content="version")
  inspect(kind_of(@moon-wipe.parse_args(["-V"])), content="version")
  // A help flag wins even when other arguments are invalid.
  inspect(kind_of(@moon-wipe.parse_args(["--nope", "--help"])), content="help")
}

///|
test "unknown option is rejected" {
  try @moon-wipe.parse_args(["--nope"]) catch {
    @moon-wipe.CliError::CliError(message) =>
      inspect(message, content="unknown option: --nope")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "unknown target is rejected" {
  try @moon-wipe.parse_args(["rust"]) catch {
    @moon-wipe.CliError::CliError(message) =>
      inspect(
        message,
        content="unknown target: rust (expected moon, mooncakes, all, or cache)",
      )
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "a second positional argument is rejected" {
  try @moon-wipe.parse_args(["moon", "all"]) catch {
    @moon-wipe.CliError::CliError(message) =>
      inspect(message, content="unexpected argument: all")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "a flag without its value is rejected" {
  try @moon-wipe.parse_args(["--root"]) catch {
    @moon-wipe.CliError::CliError(message) =>
      inspect(message, content="missing value for --root")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "parse_size understands binary units" {
  inspect(@moon-wipe.parse_size("0"), content="0")
  inspect(@moon-wipe.parse_size("100"), content="100")
  inspect(@moon-wipe.parse_size("1K"), content="1024")
  inspect(@moon-wipe.parse_size("1kb"), content="1024")
  inspect(@moon-wipe.parse_size("1KiB"), content="1024")
  inspect(@moon-wipe.parse_size("1.5M"), content="1572864")
  inspect(@moon-wipe.parse_size("2G"), content="2147483648")
  inspect(@moon-wipe.parse_size("1T"), content="1099511627776")
  inspect(@moon-wipe.parse_size(" 8 M "), content="8388608")
}

///|
test "parse_size rejects malformed input" {
  for bad in ["", "M", "1X", "abc"] {
    try @moon-wipe.parse_size(bad) catch {
      @moon-wipe.CliError::CliError(_) => ()
    } noraise {
      _ => fail("expected \{bad} to be rejected")
    }
  }
}

///|
test "older-than rejects a negative count" {
  try @moon-wipe.parse_args(["--older-than=-1"]) catch {
    @moon-wipe.CliError::CliError(message) =>
      inspect(message, content="day count must not be negative: -1")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "help text carries the version and every target" {
  assert_true(@moon-wipe.HELP.has_prefix("moon-wipe \{@moon-wipe.VERSION}"))
  for target in ["moon", "mooncakes", "all", "cache"] {
    assert_true(@moon-wipe.HELP.contains(target))
  }
}
