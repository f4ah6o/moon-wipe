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
    @wipe.Command::Help => println(@wipe.HELP)
    @wipe.Command::Version => println("moon-wipe \{@wipe.VERSION}")
    @wipe.Command::Run(options) => {
      let result = @wipe.scan(options) catch {
        error => {
          println("moon-wipe: \{error}")
          @env.exit(1)
        }
      }
      println(@wipe.render_report(result, options))
    }
  }
}
