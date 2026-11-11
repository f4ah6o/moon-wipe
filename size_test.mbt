///|
async test "dir_stats reports bytes, files, and the newest mtime" {
  let root = @fs.tmpdir(prefix="moon-wipe-size-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  @fs.write_file(@moon-wipe.join(root, "a"), b"12345")
  @fs.mkdir(@moon-wipe.join(root, "sub"), recursive=true)
  @fs.write_file(@moon-wipe.join(root, "sub/b"), b"123")
  let stats = @moon-wipe.dir_stats(root)
  inspect(stats.bytes, content="8")
  inspect(stats.files, content="2")
  assert_true(stats.newest > 0L)
}

///|
async test "dir_size agrees with dir_stats" {
  let root = @fs.tmpdir(prefix="moon-wipe-size-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  @fs.write_file(@moon-wipe.join(root, "a"), b"12345")
  @fs.mkdir(@moon-wipe.join(root, "sub"), recursive=true)
  @fs.write_file(@moon-wipe.join(root, "sub/b"), b"123")
  let (bytes, files) = @moon-wipe.dir_size(root)
  inspect(bytes, content="8")
  inspect(files, content="2")
}

///|
async test "dir_stats on an empty directory reports nothing" {
  let root = @fs.tmpdir(prefix="moon-wipe-size-")
  defer @fs.rmdir(root, recursive=true, allow_missing=true)
  let stats = @moon-wipe.dir_stats(root)
  inspect(stats.bytes, content="0")
  inspect(stats.files, content="0")
}
