///|
/// What kind of directory to look for.
#derive(Debug, Eq)
pub(all) enum Target {
  /// MoonBit build output: `_build` directories holding a `.moon_db` marker.
  Moon
  /// Dependency sources: `.mooncakes` directories holding a `.moon-lock` marker.
  Mooncakes
  /// Both `Moon` and `Mooncakes`.
  All
  /// Global caches under `~/.moon`, cleaned through `moon clean`.
  Cache
}

///|
/// Parse a target name as accepted on the command line.
///
/// # Example
/// ```mbt check
/// test {
///   debug_inspect(@moon-wipe.Target::parse("moon"), content="Moon")
///   debug_inspect(@moon-wipe.Target::parse(" mooncakes "), content="Mooncakes")
///   debug_inspect(@moon-wipe.Target::parse("all"), content="All")
///   debug_inspect(@moon-wipe.Target::parse("cache"), content="Cache")
/// }
/// ```
pub fn Target::parse(text : StringView) -> Target raise CliError {
  match text.trim() {
    "moon" => Moon
    "mooncakes" => Mooncakes
    "all" => All
    "cache" => Cache
    other =>
      raise CliError(
        "unknown target: \{other} (expected moon, mooncakes, all, or cache)",
      )
  }
}

///|
pub extend Target with @debug.Debug::{to_repr}

///|
pub extend Target with Eq::{not_equal, equal}
