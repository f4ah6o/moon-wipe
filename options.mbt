///|
/// Search and deletion settings.
pub(all) struct Options {
  /// Where the recursive search starts. Resolved to an absolute path by `scan`.
  root : String
  /// Which kind of directory to look for.
  target : Target
  /// Delete what was found instead of only reporting it.
  wipe : Bool
  /// Paths to skip. A directory is skipped when it equals an entry or lives under it.
  ignores : Array[String]
  /// Directories smaller than this are not reported.
  min_size : Int64
  /// Only report directories whose newest entry is at least this many days old.
  older_than_days : Int32?
  /// Emit machine-readable JSON instead of the human report.
  json : Bool
}

///|
/// Settings used when no flag is given: search for `_build` under the current
/// directory and report without deleting anything.
pub fn Options::new() -> Options {
  {
    root: ".",
    target: Target::Moon,
    wipe: false,
    ignores: [],
    min_size: 0L,
    older_than_days: None,
    json: false,
  }
}
