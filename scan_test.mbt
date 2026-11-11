///|
/// Create a throwaway directory tree for one test and return its root.
async fn fixture() -> String {
  @fs.tmpdir(prefix="moon-wipe-test-")
}

///|
/// Create `root/name` and, when `marker` is set, drop the marker file inside.
async fn make_dir(
  root : String,
  name : String,
  marker : String?,
  payload : Bytes,
) -> String {
  let path = @moon-wipe.join(root, name)
  @fs.mkdir(path, recursive=true)
  if marker is Some(file) {
    @fs.write_file(@moon-wipe.join(path, file), b"")
  }
  if payload.length() > 0 {
    @fs.write_file(@moon-wipe.join(path, "artifact.bin"), payload)
  }
  path
}

///|
/// Run a scan and return the entry paths, sorted for stable assertions.
async fn scan_paths(root : String, target : @moon-wipe.Target) -> Array[String] {
  let options = { ..@moon-wipe.Options::new(), root, target, }
  let result = @moon-wipe.scan(options)
  let paths = result.entries.map(entry => entry.path)
  paths.sort()
  paths
}

///|
async test "finds _build directories that carry the marker" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let project = @moon-wipe.join(root, "project")
  @fs.mkdir(project, recursive=true)
  let build = make_dir(project, "_build", Some(".moon_db"), b"0123456789")
  debug_inspect(
    scan_paths(root, @moon-wipe.Target::Moon),
    content="[\"\{build}\"]",
  )
}

///|
async test "skips _build directories without the marker" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let project = @moon-wipe.join(root, "project")
  @fs.mkdir(project, recursive=true)
  ignore(make_dir(project, "_build", None, b"0123456789"))
  debug_inspect(scan_paths(root, @moon-wipe.Target::Moon), content="[]")
}

///|
async test "does not descend into _build" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let project = @moon-wipe.join(root, "project")
  @fs.mkdir(project, recursive=true)
  let build = make_dir(project, "_build", Some(".moon_db"), b"")
  // A build directory carries a copy of the dependency sources.
  ignore(make_dir(build, ".mooncakes", Some(".moon-lock"), b"0123456789"))
  debug_inspect(
    scan_paths(root, @moon-wipe.Target::Moon),
    content="[\"\{build}\"]",
  )
  // The copy must not be reported even when only dependency sources are wanted.
  debug_inspect(scan_paths(root, @moon-wipe.Target::Mooncakes), content="[]")
}

///|
async test "all reports build output and dependency sources" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let project = @moon-wipe.join(root, "project")
  @fs.mkdir(project, recursive=true)
  let build = make_dir(project, "_build", Some(".moon_db"), b"")
  let cakes = make_dir(project, ".mooncakes", Some(".moon-lock"), b"")
  let paths = scan_paths(root, @moon-wipe.Target::All)
  inspect(paths.length(), content="2")
  assert_true(paths.contains(build))
  assert_true(paths.contains(cakes))
}

///|
async test "finds projects nested several levels deep" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let deep = @moon-wipe.join(root, "a/b/c")
  @fs.mkdir(deep, recursive=true)
  let build = make_dir(deep, "_build", Some(".moon_db"), b"")
  debug_inspect(
    scan_paths(root, @moon-wipe.Target::Moon),
    content="[\"\{build}\"]",
  )
}

///|
async test "size counts files and bytes under the match" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let project = @moon-wipe.join(root, "project")
  @fs.mkdir(project, recursive=true)
  let build = make_dir(project, "_build", Some(".moon_db"), b"0123456789")
  @fs.mkdir(@moon-wipe.join(build, "nested"), recursive=true)
  @fs.write_file(@moon-wipe.join(build, "nested/deep.bin"), b"abcde")
  let options = { ..@moon-wipe.Options::new(), root, }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="1")
  // .moon_db is empty, artifact.bin is 10 bytes, deep.bin is 5 bytes.
  inspect(result.entries[0].size, content="15")
  inspect(result.entries[0].files, content="3")
}

///|
async test "ignore marks matching entries and their children" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let kept = @moon-wipe.join(root, "kept")
  let skipped = @moon-wipe.join(root, "skipped")
  @fs.mkdir(kept, recursive=true)
  @fs.mkdir(skipped, recursive=true)
  ignore(make_dir(kept, "_build", Some(".moon_db"), b""))
  ignore(make_dir(skipped, "_build", Some(".moon_db"), b""))
  let options = { ..@moon-wipe.Options::new(), root, ignores: [skipped], }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="2")
  let ignored = result.entries
    .filter(entry => entry.ignored)
    .map(entry => entry.path)
  debug_inspect(ignored, content="[\"\{skipped}/_build\"]")
}

///|
async test "min-size drops small directories" {
  let root = fixture()
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let small = @moon-wipe.join(root, "small")
  let large = @moon-wipe.join(root, "large")
  @fs.mkdir(small, recursive=true)
  @fs.mkdir(large, recursive=true)
  ignore(make_dir(small, "_build", Some(".moon_db"), b"0123456789"))
  ignore(make_dir(large, "_build", Some(".moon_db"), Bytes::make(4096, b'x')))
  let options = { ..@moon-wipe.Options::new(), root, min_size: 1000L, }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="1")
  inspect(result.entries[0].path, content="\{large}/_build")
}

///|
async test "a missing root is reported as an error" {
  let options = { ..@moon-wipe.Options::new(), root: "/nonexistent/moon-wipe", }
  try @moon-wipe.scan(options) catch {
    _ => ()
  } noraise {
    _ => fail("expected the scan to fail")
  }
}
