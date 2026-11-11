///|
/// Delete every entry that is not ignored and return the updated entries.
///
/// Failures are recorded on the returned entry instead of aborting, so one
/// directory that cannot be removed does not stop the rest of the run.
pub async fn wipe(entries : Array[Entry]) -> Array[Entry] {
  let result : Array[Entry] = []
  for entry in entries {
    if entry.ignored {
      result.push(entry)
      continue
    }
    // `allow_missing` does not suppress a missing path, so check first.
    if !@fs.exists(entry.path) {
      result.push(entry)
      continue
    }
    let failure : Ref[String?] = Ref(None)
    @fs.rmdir(entry.path, recursive=true) catch {
      error => failure.val = Some("\{error}")
    }
    result.push({ ..entry, error: failure.val, })
  }
  result
}
