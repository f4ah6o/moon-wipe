///|
/// A result with one clean entry and one that failed to be removed.
fn json_sample_result() -> @moon-wipe.ScanResult {
  {
    root: "/code",
    entries: [
      @moon-wipe.Entry::new("/code/a/_build", 1536L, 12),
      {
        ..@moon-wipe.Entry::new("/code/b/_build", 2048L, 3),
        error: Some("denied"),
      },
    ],
  }
}

///|
test "json report has the documented shape" {
  inspect(
    @moon-wipe.render_json(json_sample_result(), @moon-wipe.Options::new()),
    content=(
      #|{
      #|  "version": "0.1.1",
      #|  "root": "/code",
      #|  "target": "moon",
      #|  "wiped": false,
      #|  "entries": [
      #|    {
      #|      "path": "/code/a/_build",
      #|      "size": 1536,
      #|      "files": 12,
      #|      "ignored": false,
      #|      "error": null
      #|    },
      #|    {
      #|      "path": "/code/b/_build",
      #|      "size": 2048,
      #|      "files": 3,
      #|      "ignored": false,
      #|      "error": "denied"
      #|    }
      #|  ],
      #|  "total": {
      #|    "directories": 2,
      #|    "size": 3584,
      #|    "files": 15
      #|  }
      #|}
    ),
  )
}

///|
test "json report records the target and the wipe flag" {
  let options = {
    ..@moon-wipe.Options::new(),
    target: @moon-wipe.Target::All,
    wipe: true,
  }
  inspect(
    @moon-wipe.render_json(json_sample_result(), options),
    content=(
      #|{
      #|  "version": "0.1.1",
      #|  "root": "/code",
      #|  "target": "all",
      #|  "wiped": true,
      #|  "entries": [
      #|    {
      #|      "path": "/code/a/_build",
      #|      "size": 1536,
      #|      "files": 12,
      #|      "ignored": false,
      #|      "error": null
      #|    },
      #|    {
      #|      "path": "/code/b/_build",
      #|      "size": 2048,
      #|      "files": 3,
      #|      "ignored": false,
      #|      "error": "denied"
      #|    }
      #|  ],
      #|  "total": {
      #|    "directories": 2,
      #|    "size": 3584,
      #|    "files": 15
      #|  }
      #|}
    ),
  )
}

///|
test "json report of an empty result still carries the totals" {
  let result : @moon-wipe.ScanResult = { root: "/code", entries: [], }
  inspect(
    @moon-wipe.render_json(result, @moon-wipe.Options::new()),
    content=(
      #|{
      #|  "version": "0.1.1",
      #|  "root": "/code",
      #|  "target": "moon",
      #|  "wiped": false,
      #|  "entries": [],
      #|  "total": {
      #|    "directories": 0,
      #|    "size": 0,
      #|    "files": 0
      #|  }
      #|}
    ),
  )
}
