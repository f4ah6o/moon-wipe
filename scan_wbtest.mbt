///|
test "is_old_enough compares the newest mtime against the cutoff" {
  let stats : DirStats = { bytes: 0L, files: 0, newest: 100L, }
  assert_true(is_old_enough(stats, None))
  assert_true(is_old_enough(stats, Some(200L)))
  assert_false(is_old_enough(stats, Some(100L)))
  assert_false(is_old_enough(stats, Some(50L)))
}

///|
test "age_cutoff is empty without the flag" {
  debug_inspect(age_cutoff(Options::new()), content="None")
}

///|
test "age_cutoff subtracts the requested days" {
  let options = { ..Options::new(), older_than_days: Some(30), }
  let cutoff = age_cutoff(options).unwrap()
  let expected = now_seconds() - 30L * 86400L
  let drift = if cutoff > expected {
    cutoff - expected
  } else {
    expected - cutoff
  }
  assert_true(drift <= 2L)
}
