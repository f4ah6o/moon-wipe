///|
async fn main {
  let args = @env.args()
  let command = @wipe.parse_args(args[1:]) catch {
    @wipe.CliError::CliError(message) => {
      println("moon-wipe: \{message}")
      println("Try 'moon-wipe --help' for more information.")
      @env.exit(2)
    }
  }
  match command {
    @wipe.Command::Help => println(@wipe.help_text())
    @wipe.Command::Version => println("moon-wipe \{@wipe.VERSION}")
    @wipe.Command::Run(options) => {
      let result = @wipe.scan(options) catch {
        error => {
          println("moon-wipe: \{error}")
          @env.exit(1)
        }
      }
      let entries = if options.wipe {
        @wipe.wipe(result.entries)
      } else {
        result.entries
      }
      let updated = { ..result, entries, }
      let text = if options.json {
        @wipe.render_json(updated, options)
      } else {
        @wipe.render_report(updated, options)
      }
      println(text)
    }
  }
}
