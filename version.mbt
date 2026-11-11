///|
/// Version reported by `--version` and in the report header.
pub const VERSION : String = "0.1.0"

///|
/// Usage text printed by `--help`.
pub const HELP : String =
  #|moon-wipe \{VERSION}
  #|Recursively find and optionally wipe MoonBit build directories.
  #|
  #|Usage: moon-wipe [TARGET] [OPTIONS]
  #|
  #|Targets:
  #|  moon         _build directories (default)
  #|  mooncakes    .mooncakes dependency sources
  #|  all          moon + mooncakes
  #|  cache        global caches under ~/.moon
  #|
  #|Options:
  #|  -w, --wipe              Delete what was found (default is a dry run)
  #|  -i, --ignore <PATH>     Skip this path; repeatable
  #|      --root <PATH>       Start searching here (default: current directory)
  #|      --min-size <SIZE>   Only report directories at least this large (e.g. 100M)
  #|      --older-than <DAYS> Only report directories untouched for this many days
  #|      --json              Emit machine-readable JSON
  #|  -h, --help              Print this help
  #|  -V, --version           Print the version
