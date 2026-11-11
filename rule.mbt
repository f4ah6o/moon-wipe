///|
/// A directory name to look for, plus the marker file that proves the
/// directory really belongs to MoonBit.
#derive(Debug, Eq)
pub(all) struct Rule {
  dir_name : String
  marker : String
}

///|
/// The rules a target expands to.
///
/// # Example
/// ```mbt check
/// test {
///   debug_inspect(
///     @moon-wipe.Target::Moon.rules(),
///     content="[{ dir_name: \"_build\", marker: \".moon_db\" }]",
///   )
///   debug_inspect(@moon-wipe.Target::All.rules().length(), content="2")
///   debug_inspect(@moon-wipe.Target::Cache.rules().length(), content="0")
/// }
/// ```
pub fn Target::rules(self : Target) -> Array[Rule] {
  match self {
    Moon => [{ dir_name: "_build", marker: ".moon_db", }]
    Mooncakes => [{ dir_name: ".mooncakes", marker: ".moon-lock", }]
    All =>
      [
        { dir_name: "_build", marker: ".moon_db", },
        { dir_name: ".mooncakes", marker: ".moon-lock", },
      ]
    Cache => []
  }
}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub extend Rule with Eq::{not_equal, equal}
