///|
/// One directory that matched, with the space it occupies.
#derive(Debug)
pub(all) struct Entry {
  path : String
  size : Int64
  files : Int32
  /// The path matched an `--ignore` entry, so `--wipe` leaves it alone.
  ignored : Bool
  /// Set when measuring or deleting the directory failed.
  mut error : String?
}

///|
/// A freshly measured entry that has not been filtered or deleted yet.
pub fn Entry::new(path : String, size : Int64, files : Int32) -> Entry {
  { path, size, files, ignored: false, error: None, }
}

///|
pub extend Entry with @debug.Debug::{to_repr}
