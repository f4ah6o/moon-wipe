///|
/// Two entries of different sizes, used by the rendering tests.
fn sample_result() -> @moon-wipe.ScanResult {
  {
    root: "/code",
    entries: [
      @moon-wipe.Entry::new("/code/a/_build", 1536L, 12),
      @moon-wipe.Entry::new("/code/b/_build", 1048576L, 3),
    ],
  }
}

///|
test "report lists every entry and ends with a dry-run hint" {
  inspect(
    @moon-wipe.render_report(sample_result(), @moon-wipe.Options::new()),
    content=(
      #|moon-wipe 0.1.0
      #|Searching for MoonBit build directories in /code
      #|
      #|  /code/a/_build  1.5 KiB  12 files
      #|  /code/b/_build  1.0 MiB   3 files
      #|
      #|Found 2 directories, 1.0 MiB, 15 files
      #|Dry run: re-run with -w to delete
    ),
  )
}

///|
test "report says nothing was found" {
  let result : @moon-wipe.ScanResult = { root: "/code", entries: [], }
  inspect(
    @moon-wipe.render_report(result, @moon-wipe.Options::new()),
    content=(
      #|moon-wipe 0.1.0
      #|Searching for MoonBit build directories in /code
      #|
      #|Nothing to wipe.
    ),
  )
}

///|
test "report switches the footer when wiping" {
  let options = { ..@moon-wipe.Options::new(), wipe: true, }
  inspect(
    @moon-wipe.render_report(sample_result(), options),
    content=(
      #|moon-wipe 0.1.0
      #|Searching for MoonBit build directories in /code
      #|
      #|  /code/a/_build  1.5 KiB  12 files
      #|  /code/b/_build  1.0 MiB   3 files
      #|
      #|Found 2 directories, 1.0 MiB, 15 files
      #|Wiped 2 directories, freed 1.0 MiB
    ),
  )
}

///|
test "report marks ignored entries" {
  let result : @moon-wipe.ScanResult = {
    root: "/code",
    entries: [
      { ..@moon-wipe.Entry::new("/code/a/_build", 1024L, 1), ignored: true, },
    ],
  }
  inspect(
    @moon-wipe.render_report(result, @moon-wipe.Options::new()),
    content=(
      #|moon-wipe 0.1.0
      #|Searching for MoonBit build directories in /code
      #|
      #|  /code/a/_build  1.0 KiB  1 file  (ignored)
      #|
      #|Found 1 directory, 1.0 KiB, 1 file (1 ignored)
      #|Dry run: re-run with -w to delete
    ),
  )
}
