import common
import flag
import os

const app_name = 'mktemp'

struct Options {
	directory bool
	dry_run   bool
	quiet     bool
	suffix    string
	tmp_dir   string
	templates []string
}

fn get_options() Options {
	mut fp := flag.new_flag_parser(os.args)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.application(app_name)
	fp.limit_free_args(0, 1) or {}
	fp.arguments_description('[TEMPLATE]')
	fp.description("\n
                Create a temporary file or directory, safely, and print its name.
                TEMPLATE must contain at least 3 consecutive 'X's. If TEMPLATE is
                not specified, use tmp.XXXXXXXXXX, and --tmpdir is implied. Files
                are created u+rw, and directories u+rwx, minus umask restrictions.".trim_indent())

	fp.footer("\nX's can occur anywhere in the TEMPLATE. Multiple groups of X's\nare allowed (e.g. tmpXXX_XXXX.txt)")
	fp.footer(common.coreutils_footer())

	directory := fp.bool('directory', `d`, false, 'create a directory, not a file')
	dry_run := fp.bool('dry-run', `u`, false, 'do not create anything; merely print a name')
	quiet := fp.bool('quiet', `q`, false, 'suppress diagnostics about file/dir-creation failure')
	suffix := fp.string('suffix', ` `, '', 'append <string> to TEMPLATE; <string> must not contain a slash.')
	tmp_dir := fp.string('tmpdir', `p`, '', 'interpret TEMPLATE relative to directory <string>\n')
	templates := fp.finalize() or { exit_error(err.msg()) }

	return Options{
		directory: directory
		dry_run:   dry_run
		quiet:     quiet
		suffix:    suffix
		tmp_dir:   tmp_dir
		templates: templates
	}
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}

@[noreturn]
fn exit_notify(msg string, options Options) {
	if options.quiet {
		exit(1)
	}
	common.exit_with_error_message(app_name, msg)
}
