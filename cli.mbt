///|
/// What the command line asked for.
pub(all) enum Command {
  Run(Options)
  Help
  Version
}

///|
/// Parse the arguments that follow the program name.
///
/// # Example
/// ```mbt check
/// test {
///   let command = @moon-wipe.parse_args(["-w", "mooncakes"])
///   guard command is Run(options) else { fail("expected Run") }
///   inspect(options.wipe, content="true")
///   debug_inspect(options.target, content="Mooncakes")
/// }
/// ```
pub fn parse_args(args : ArrayView[String]) -> Command raise CliError {
  // Help and version win over every other argument, including invalid ones.
  for arg in args {
    if arg == "-h" || arg == "--help" {
      return Command::Help
    }
  }
  for arg in args {
    if arg == "-V" || arg == "--version" {
      return Command::Version
    }
  }
  let mut root = "."
  let mut target = Target::Moon
  let mut target_given = false
  let mut wipe = false
  let mut min_size = 0L
  let mut older_than_days : Int32? = None
  let mut json = false
  let ignores : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    index += 1
    if arg == "-w" || arg == "--wipe" {
      wipe = true
    } else if arg == "--json" {
      json = true
    } else if arg == "-i" || arg == "--ignore" {
      ignores.push(take_value(args, index, arg))
      index += 1
    } else if arg == "--root" {
      root = take_value(args, index, arg)
      index += 1
    } else if arg == "--min-size" {
      min_size = parse_size(take_value(args, index, arg))
      index += 1
    } else if arg == "--older-than" {
      older_than_days = Some(parse_days(take_value(args, index, arg)))
      index += 1
    } else if arg.has_prefix("--ignore=") {
      ignores.push(arg[9:].to_owned())
    } else if arg.has_prefix("--root=") {
      root = arg[7:].to_owned()
    } else if arg.has_prefix("--min-size=") {
      min_size = parse_size(arg[11:])
    } else if arg.has_prefix("--older-than=") {
      older_than_days = Some(parse_days(arg[13:]))
    } else if arg.has_prefix("-") && arg != "-" {
      raise CliError("unknown option: \{arg}")
    } else if target_given {
      raise CliError("unexpected argument: \{arg}")
    } else {
      target = Target::parse(arg)
      target_given = true
    }
  }
  Command::Run({ root, target, wipe, ignores, min_size, older_than_days, json, })
}

///|
/// Read the value that follows a flag, or fail when the flag is last.
fn take_value(
  args : ArrayView[String],
  index : Int32,
  flag : String,
) -> String raise CliError {
  guard index < args.length() else {
    raise CliError("missing value for \{flag}")
  }
  args[index]
}

///|
/// Parse a byte count such as `100`, `512K`, `1.5G`, or `2GiB`.
///
/// Units are binary: `K` is 1024 bytes. A bare number is taken as bytes.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@moon-wipe.parse_size("100"), content="100")
///   inspect(@moon-wipe.parse_size("1K"), content="1024")
///   inspect(@moon-wipe.parse_size("1.5M"), content="1572864")
///   inspect(@moon-wipe.parse_size("2GiB"), content="2147483648")
/// }
/// ```
pub fn parse_size(text : StringView) -> Int64 raise CliError {
  let trimmed = text.trim()
  guard !trimmed.is_empty() else { raise CliError("empty size") }
  let mut digits = 0
  while digits < trimmed.length() {
    let c = trimmed[digits]
    guard (c >= '0' && c <= '9') || c == '.' else { break }
    digits += 1
  }
  guard digits > 0 else { raise CliError("invalid size: \{trimmed}") }
  let number = @string.parse_double(trimmed[:digits]) catch {
    _ => raise CliError("invalid size: \{trimmed}")
  }
  let unit = trimmed[digits:].trim().to_lower()
  let factor = match unit {
    "" | "b" => 1L
    "k" | "kb" | "kib" => 1024L
    "m" | "mb" | "mib" => 1024L * 1024L
    "g" | "gb" | "gib" => 1024L * 1024L * 1024L
    "t" | "tb" | "tib" => 1024L * 1024L * 1024L * 1024L
    _ => raise CliError("unknown size unit: \{unit}")
  }
  (number * factor.to_double()).to_int64()
}

///|
/// Parse a non-negative day count.
fn parse_days(text : StringView) -> Int32 raise CliError {
  let days = @string.parse_int(text.trim()) catch {
    _ => raise CliError("invalid day count: \{text}")
  }
  guard days >= 0 else {
    raise CliError("day count must not be negative: \{text}")
  }
  days
}
