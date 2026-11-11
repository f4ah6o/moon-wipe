///|
/// Create a project holding a marked `_build` directory and return both paths.
async fn project_with_build(root : String, name : String) -> (String, String) {
  let project = @moon-wipe.join(root, name)
  let build = @moon-wipe.join(project, "_build")
  @fs.mkdir(build, recursive=true)
  @fs.write_file(@moon-wipe.join(build, ".moon_db"), b"")
  @fs.write_file(@moon-wipe.join(build, "artifact.bin"), b"0123456789")
  (project, build)
}

///|
async test "wipe removes matching directories and keeps their parents" {
  let root = @fs.tmpdir(prefix="moon-wipe-wipe-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let (project, build) = project_with_build(root, "project")
  let options = { ..@moon-wipe.Options::new(), root, wipe: true, }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="1")
  let wiped = @moon-wipe.wipe(result.entries)
  debug_inspect(wiped[0].error, content="None")
  assert_false(@fs.exists(build))
  assert_true(@fs.exists(project))
}

///|
async test "wipe leaves ignored entries alone" {
  let root = @fs.tmpdir(prefix="moon-wipe-wipe-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let (project, build) = project_with_build(root, "project")
  let options = { ..@moon-wipe.Options::new(), root, ignores: [project], }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="1")
  inspect(result.entries[0].ignored, content="true")
  ignore(@moon-wipe.wipe(result.entries))
  assert_true(@fs.exists(build))
}

///|
async test "wipe records a failure instead of aborting the run" {
  let root = @fs.tmpdir(prefix="moon-wipe-wipe-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let file = @moon-wipe.join(root, "not-a-directory")
  @fs.write_file(file, b"x")
  let entries = [
    @moon-wipe.Entry::new(file, 1L, 1),
    @moon-wipe.Entry::new(@moon-wipe.join(root, "already-gone"), 0L, 0),
  ]
  let wiped = @moon-wipe.wipe(entries)
  // Removing a regular file as a directory fails and is reported.
  assert_true(wiped[0].error is Some(_))
  // A path that is already gone is not an error.
  debug_inspect(wiped[1].error, content="None")
}

///|
async test "wipe clears several projects in one run" {
  let root = @fs.tmpdir(prefix="moon-wipe-wipe-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let (_, first) = project_with_build(root, "a")
  let (_, second) = project_with_build(root, "b")
  let options = { ..@moon-wipe.Options::new(), root, wipe: true, }
  let result = @moon-wipe.scan(options)
  inspect(result.entries.length(), content="2")
  ignore(@moon-wipe.wipe(result.entries))
  assert_false(@fs.exists(first))
  assert_false(@fs.exists(second))
}
