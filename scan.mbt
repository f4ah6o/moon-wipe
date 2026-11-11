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
/// Find every directory that matches the target.
///
/// `Moon`, `Mooncakes`, and `All` walk `options.root`. `Cache` looks at the
/// global caches instead, which live outside any project.
pub async fn scan(options : Options) -> ScanResult {
  match options.target {
    Cache => scan_cache(options)
    _ => scan_tree(options)
  }
}

///|
/// Walk `options.root` looking for the target's directories.
///
/// The walk prunes at every directory whose name matches a rule, whether or
/// not the marker is present. A `_build` directory contains a copy of
/// `.mooncakes`, so descending past a match would report the same dependency
/// tree once per build profile.
async fn scan_tree(options : Options) -> ScanResult {
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
  let cutoff = age_cutoff(options)
  let entries : Array[Entry] = []
  for path in found {
    let stats = dir_stats(path)
    guard stats.bytes >= options.min_size else { continue }
    guard is_old_enough(stats, cutoff) else { continue }
    entries.push({
      path,
      size: stats.bytes,
      files: stats.files,
      ignored: is_ignored(path, ignores),
      error: None,
    })
  }
  { root, entries, }
}

///|
/// Measure the global caches, which live outside any project.
async fn scan_cache(options : Options) -> ScanResult {
  measure_caches(cache_dirs(), moon_home(), options)
}

///|
/// Measure the given cache directories, skipping the ones that do not exist.
pub async fn measure_caches(
  dirs : Array[String],
  root : String,
  options : Options,
) -> ScanResult {
  let ignores : Array[String] = []
  for ignore in options.ignores {
    ignores.push(resolve_path(root, ignore))
  }
  let cutoff = age_cutoff(options)
  let entries : Array[Entry] = []
  for path in dirs {
    guard @fs.exists(path) else { continue }
    let stats = dir_stats(path)
    guard stats.bytes >= options.min_size else { continue }
    guard is_old_enough(stats, cutoff) else { continue }
    entries.push({
      path,
      size: stats.bytes,
      files: stats.files,
      ignored: is_ignored(path, ignores),
      error: None,
    })
  }
  { root, entries, }
}

///|
/// The MoonBit home directory, honouring `MOON_HOME` when set.
fn moon_home() -> String raise ScanError {
  if @env.get_env_var("MOON_HOME") is Some(home) {
    return strip_trailing_slash(home)
  }
  guard @env.get_env_var("HOME") is Some(home) else {
    raise ScanError(
      "cannot locate the MoonBit home: neither MOON_HOME nor HOME is set",
    )
  }
  join(home, ".moon")
}

///|
/// The global cache directories, honouring the per-cache overrides.
fn cache_dirs() -> Array[String] raise ScanError {
  cache_dirs_from(
    moon_home(),
    @env.get_env_var("MOON_DEP_CACHE"),
    @env.get_env_var("MOON_REGISTRY_CACHE"),
  )
}

///|
/// Resolve the cache directories from an explicit home and overrides.
///
/// # Example
/// ```mbt check
/// test {
///   debug_inspect(
///     @moon-wipe.cache_dirs_from("/home/u/.moon", None, None),
///     content="[\"/home/u/.moon/cache\", \"/home/u/.moon/registry\"]",
///   )
///   debug_inspect(
///     @moon-wipe.cache_dirs_from("/home/u/.moon", Some("/d"), Some("/r")),
///     content="[\"/d\", \"/r\"]",
///   )
/// }
/// ```
pub fn cache_dirs_from(
  home : StringView,
  dep_cache : String?,
  registry_cache : String?,
) -> Array[String] {
  let dep = match dep_cache {
    Some(path) => strip_trailing_slash(path)
    None => join(home, "cache")
  }
  let registry = match registry_cache {
    Some(path) => strip_trailing_slash(path)
    None => join(home, "registry")
  }
  [dep, registry]
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

///|
/// Seconds since the Unix epoch.
///
/// `@env.now()` is milliseconds and stays well below 2^63, so reinterpreting
/// the bits as a signed integer is safe here.
fn now_seconds() -> Int64 {
  @env.now().reinterpret_as_int64() / 1000L
}

///|
/// The oldest modification time an entry may have to still be reported.
fn age_cutoff(options : Options) -> Int64? {
  match options.older_than_days {
    Some(days) => Some(now_seconds() - days.to_int64() * 86400L)
    None => None
  }
}

///|
/// True when the entry is old enough to report, or when no age filter is set.
fn is_old_enough(stats : DirStats, cutoff : Int64?) -> Bool {
  match cutoff {
    Some(limit) => stats.newest < limit
    None => true
  }
}
