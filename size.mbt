///|
/// What a directory occupies and when it was last touched.
#derive(Debug)
pub(all) struct DirStats {
  bytes : Int64
  files : Int32
  /// Newest modification time under the directory, in seconds since the Unix
  /// epoch. Zero when nothing could be read.
  newest : Int64
}

///|
/// Measure `path` without following symlinks.
///
/// A link cycle cannot hang the walk and a linked tree is not counted twice.
/// Unreadable subdirectories are skipped rather than aborting the measurement.
pub async fn dir_stats(path : StringView) -> DirStats {
  let bytes : Ref[Int64] = Ref(0L)
  let files : Ref[Int32] = Ref(0)
  let newest : Ref[Int64] = Ref(0L)
  let pending : Array[String] = [path.to_owned()]
  while !pending.is_empty() {
    let dir = pending.pop().unwrap()
    touch(dir, newest)
    let names = @fs.readdir(dir, include_hidden=true, sort=true) catch {
      _ => continue
    }
    for name in names {
      let child = join(dir, name)
      let kind = @fs.kind(child, follow_symlink=false) catch { _ => continue }
      match kind {
        Directory => pending.push(child)
        Regular => {
          bytes.val = bytes.val + (@fs.file_size(child) catch { _ => 0L })
          files.val = files.val + 1
          touch(child, newest)
        }
        _ => ()
      }
    }
  }
  { bytes: bytes.val, files: files.val, newest: newest.val, }
}

///|
/// Total bytes and file count under `path`.
pub async fn dir_size(path : StringView) -> (Int64, Int32) {
  let stats = dir_stats(path)
  (stats.bytes, stats.files)
}

///|
/// Record `path`'s modification time when it is newer than `newest`.
async fn touch(path : StringView, newest : Ref[Int64]) -> Unit {
  let (seconds, _) = @fs.mtime(path) catch { _ => (-1L, 0) }
  if seconds > newest.val {
    newest.val = seconds
  }
}

///|
pub extend DirStats with @debug.Debug::{to_repr}
