///|
/// Render the machine-readable report.
///
/// The shape is stable: `root`, `target`, `wiped`, `entries`, and `total`.
/// `error` is `null` for entries that were measured or removed cleanly.
pub fn render_json(result : ScanResult, options : Options) -> String {
  let entries : Array[Json] = []
  for entry in result.entries {
    entries.push({
      "path": entry.path,
      "size": Json::number(entry.size.to_double()),
      "files": entry.files,
      "ignored": entry.ignored,
      "error": match entry.error {
        Some(message) => Json::string(message)
        None => @json.null
      },
    })
  }
  let total_size = result.entries.fold(init=0L, (sum, entry) => sum + entry.size)
  let total_files = result.entries.fold(init=0, (sum, entry) => {
    sum + entry.files
  })
  let document : Json = {
    "version": VERSION,
    "root": result.root,
    "target": options.target.name(),
    "wiped": options.wipe,
    "entries": entries,
    "total": {
      "directories": result.entries.length(),
      "size": Json::number(total_size.to_double()),
      "files": total_files,
    },
  }
  document.stringify(indent=2)
}
