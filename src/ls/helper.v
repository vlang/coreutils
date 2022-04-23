const (
	name = 'ls'
)

// Based on the exit status of actual ls
enum EXIT_STATUS {
	success = 0
	minor_err = 1
	major_err = 2
}

fn run_ls(args []string) {
	println('Running ls')
}

[noreturn]
fn success_exit(msg string) {
	println(msg)
	exit(int(EXIT_STATUS.success))
}

[noreturn]
fn error_exit(msg string, status EXIT_STATUS) {
	eprintln(msg)
	exit(int(status))
}
