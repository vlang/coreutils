module main

// POSIX Spec: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/unlink.html
const app_name = 'unlink'
const app_description = 'call the unlink function to remove the specified file'

@[noreturn]
pub fn fail(error string) {
	eprintln('${app_name}: ${error}')
	exit(1)
}

fn main() {
	unlink(args())
}
