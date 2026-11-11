///|
/// Format a byte count with binary units.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@moon-wipe.format_bytes(0), content="0 B")
///   inspect(@moon-wipe.format_bytes(512), content="512 B")
///   inspect(@moon-wipe.format_bytes(1024), content="1.0 KiB")
///   inspect(@moon-wipe.format_bytes(1536), content="1.5 KiB")
///   inspect(@moon-wipe.format_bytes(1048576), content="1.0 MiB")
///   inspect(@moon-wipe.format_bytes(1099511627776), content="1.0 TiB")
/// }
/// ```
pub fn format_bytes(bytes : Int64) -> String {
  let units : Array[String] = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
  let mut value = bytes.to_double()
  let mut unit = 0
  while value >= 1024.0 && unit < units.length() - 1 {
    value = value / 1024.0
    unit += 1
  }
  if unit == 0 {
    "\{bytes} B"
  } else {
    "\{format_one_decimal(value)} \{units[unit]}"
  }
}

///|
/// Render a non-negative value with exactly one decimal place.
fn format_one_decimal(value : Double) -> String {
  let tenths = (value * 10.0 + 0.5).to_int64()
  "\{tenths / 10L}.\{tenths % 10L}"
}

///|
/// Insert thousands separators into a non-negative integer.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@moon-wipe.group_digits(0), content="0")
///   inspect(@moon-wipe.group_digits(999), content="999")
///   inspect(@moon-wipe.group_digits(1000), content="1,000")
///   inspect(@moon-wipe.group_digits(1234567), content="1,234,567")
/// }
/// ```
pub fn group_digits(value : Int64) -> String {
  let digits = value.to_string()
  let length = digits.length()
  let buffer = StringBuilder()
  for i in 0..<length {
    if i > 0 && (length - i) % 3 == 0 {
      buffer.write_string(",")
    }
    if digits.get_char(i) is Some(c) {
      buffer.write_char(c)
    }
  }
  buffer.to_string()
}

///|
/// Human name for what a target looks for.
fn describe(target : Target) -> String {
  match target {
    Moon => "MoonBit build directories"
    Mooncakes => "MoonBit dependency sources"
    All => "MoonBit build directories and dependency sources"
    Cache => "MoonBit global caches"
  }
}

///|
/// Render the report shown to the user.
///
/// The result has no trailing newline so callers can decide how to emit it.
pub fn render_report(result : ScanResult, options : Options) -> String {
  let buffer = StringBuilder()
  buffer.write_string("moon-wipe \{VERSION}\n")
  buffer.write_string(
    "Searching for \{describe(options.target)} in \{result.root}",
  )
  if result.entries.is_empty() {
    buffer.write_string("\n\nNothing to wipe.")
    return buffer.to_string()
  }
  let path_width = result.entries.fold(init=0, (width, entry) => {
    let length = entry.path.length()
    if length > width {
      length
    } else {
      width
    }
  })
  let size_width = result.entries.fold(init=0, (width, entry) => {
    let length = format_bytes(entry.size).length()
    if length > width {
      length
    } else {
      width
    }
  })
  let files_width = result.entries.fold(init=0, (width, entry) => {
    let length = group_digits(entry.files.to_int64()).length()
    if length > width {
      length
    } else {
      width
    }
  })
  buffer.write_string("\n\n")
  for entry in result.entries {
    buffer.write_string("  ")
    buffer.write_string(entry.path.pad_end(path_width, ' '))
    buffer.write_string("  ")
    buffer.write_string(format_bytes(entry.size).pad_start(size_width, ' '))
    buffer.write_string("  ")
    buffer.write_string(
      group_digits(entry.files.to_int64()).pad_start(files_width, ' '),
    )
    buffer.write_string(" \{plural(entry.files, "file", "files")}")
    if entry.ignored {
      buffer.write_string("  (ignored)")
    }
    if entry.error is Some(message) {
      buffer.write_string("  (failed: \{message})")
    }
    buffer.write_string("\n")
  }
  let total_size = result.entries.fold(init=0L, (sum, entry) => sum + entry.size)
  let total_files = result.entries.fold(init=0, (sum, entry) => {
    sum + entry.files
  })
  let count = result.entries.length()
  buffer.write_string(
    "\nFound \{count} \{plural(count, "directory", "directories")}, ",
  )
  buffer.write_string("\{format_bytes(total_size)}, ")
  buffer.write_string(
    "\{group_digits(total_files.to_int64())} \{plural(total_files, "file", "files")}",
  )
  let ignored = result.entries.filter(entry => entry.ignored).length()
  if ignored > 0 {
    buffer.write_string(" (\{ignored} ignored)")
  }
  if options.wipe {
    let wiped = result.entries.filter(entry => {
      !entry.ignored && entry.error is None
    })
    let freed = wiped.fold(init=0L, (sum, entry) => sum + entry.size)
    buffer.write_string(
      "\nWiped \{wiped.length()} \{plural(wiped.length(), "directory", "directories")}, freed \{format_bytes(freed)}",
    )
  } else {
    buffer.write_string("\nDry run: re-run with -w to delete")
  }
  let failed = result.entries.filter(entry => entry.error is Some(_)).length()
  if failed > 0 {
    buffer.write_string(
      "\n\{failed} \{plural(failed, "directory", "directories")} could not be removed",
    )
  }
  buffer.to_string()
}

///|
/// Pick the singular or plural form for `count`.
fn plural(count : Int32, singular : String, plural : String) -> String {
  if count == 1 {
    singular
  } else {
    plural
  }
}
