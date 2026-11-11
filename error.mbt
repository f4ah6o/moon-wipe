///|
/// A command line that could not be understood.
pub(all) suberror CliError {
  CliError(String)
}

///|
/// A problem that stops the run before anything can be reported.
pub(all) suberror ScanError {
  ScanError(String)
}
