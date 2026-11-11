///|
/// Total bytes and file count under `path`.
///
/// Symbolic links are not followed, so a link cycle cannot hang the walk and
/// a linked tree is not counted twice. Unreadable subdirectories are skipped
/// rather than aborting the measurement.
pub async fn dir_size(path : StringView) -> (Int64, Int32) {
  let bytes : Ref[Int64] = Ref(0L)
  let files : Ref[Int32] = Ref(0)
  let pending : Array[String] = [path.to_owned()]
  while !pending.is_empty() {
    let dir = pending.pop().unwrap()
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
        }
        _ => ()
      }
    }
  }
  (bytes.val, files.val)
}
