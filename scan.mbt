///|
/// The outcome of a search.
#derive(Debug)
pub(all) struct ScanResult {
  /// Absolute path the search started from.
  root : String
  /// Matching directories, in the order the walk reached them.
  entries : Array[Entry]
}

///|
/// Find every directory under `options.root` that matches the target.
///
/// The walk prunes at every directory whose name matches a rule, whether or
/// not the marker is present. A `_build` directory contains a copy of
/// `.mooncakes`, so descending past a match would report the same dependency
/// tree once per build profile.
pub async fn scan(options : Options) -> ScanResult {
  let root = @fs.realpath(options.root)
  let rules = options.target.rules()
  let found : Array[String] = []
  let pending : Array[String] = [root]
  while !pending.is_empty() {
    let dir = pending.pop().unwrap()
    let names = @fs.readdir(dir, include_hidden=true, sort=true) catch {
      _ => continue
    }
    for name in names {
      let path = join(dir, name)
      let kind = @fs.kind(path, follow_symlink=false) catch { _ => continue }
      guard kind is Directory else { continue }
      guard !is_vcs_dir(name) else { continue }
      if is_artifact_dir(name) {
        // Never descend, even when the current target does not look for this
        // name: `_build` holds a copy of `.mooncakes`.
        match find_rule(rules, name) {
          Some(rule) =>
            if @fs.exists(join(path, rule.marker)) {
              found.push(path)
            }
          None => ()
        }
      } else {
        pending.push(path)
      }
    }
  }
  let ignores : Array[String] = []
  for ignore in options.ignores {
    ignores.push(resolve_path(root, ignore))
  }
  let entries : Array[Entry] = []
  for path in found {
    let (size, files) = dir_size(path)
    guard size >= options.min_size else { continue }
    entries.push({
      path,
      size,
      files,
      ignored: is_ignored(path, ignores),
      error: None,
    })
  }
  { root, entries, }
}

///|
/// Make `path` absolute relative to `root`, resolving it when it exists.
async fn resolve_path(root : StringView, path : StringView) -> String {
  let candidate = if path.has_prefix("/") {
    path.to_owned()
  } else {
    join(root, path)
  }
  @fs.realpath(candidate) catch {
    _ => strip_trailing_slash(candidate)
  }
}

///|
/// True when `path` is one of `ignores` or lives under one of them.
fn is_ignored(path : StringView, ignores : Array[String]) -> Bool {
  ignores.any(ignore => path == ignore || path.has_prefix("\{ignore}/"))
}

///|
/// Directory names that hold MoonBit artifacts. The walk never descends into
/// one, whatever the current target is looking for.
fn is_artifact_dir(name : StringView) -> Bool {
  name == "_build" || name == ".mooncakes"
}

///|
/// The rule whose directory name is `name`, if any.
fn find_rule(rules : Array[Rule], name : String) -> Rule? {
  match rules.search_by(rule => rule.dir_name == name) {
    Some(index) => Some(rules[index])
    None => None
  }
}

///|
pub extend ScanResult with @debug.Debug::{to_repr}
