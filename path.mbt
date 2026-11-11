///|
/// Join a directory and a child name with exactly one separator.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@moon-wipe.join("/a", "b"), content="/a/b")
///   inspect(@moon-wipe.join("/a/", "b"), content="/a/b")
///   inspect(@moon-wipe.join("/", "b"), content="/b")
/// }
/// ```
pub fn join(dir : StringView, name : StringView) -> String {
  if dir.has_suffix("/") {
    "\{dir}\{name}"
  } else {
    "\{dir}/\{name}"
  }
}

///|
/// Drop trailing separators, keeping a lone `/` intact.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@moon-wipe.strip_trailing_slash("/a/b/"), content="/a/b")
///   inspect(@moon-wipe.strip_trailing_slash("/a/b///"), content="/a/b")
///   inspect(@moon-wipe.strip_trailing_slash("/"), content="/")
///   inspect(@moon-wipe.strip_trailing_slash("/a/b"), content="/a/b")
/// }
/// ```
pub fn strip_trailing_slash(path : StringView) -> String {
  let mut end = path.length()
  while end > 1 && path[end - 1] == '/' {
    end -= 1
  }
  path[:end].to_owned()
}

///|
/// Version-control metadata never holds build output, so the walk skips it.
fn is_vcs_dir(name : StringView) -> Bool {
  name == ".git" || name == ".hg" || name == ".svn"
}
