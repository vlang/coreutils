module main

import os
import common

const (
	app_name        = 'mkdir'
	app_description = 'Create the DIRECTORY(ies), if they do not already exist.
'
)

struct Settings {
	mode     int
	parents  bool
	verbose  bool
	dirnames []string
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	mkdir(args())
}

fn mkdir(settings Settings) {
	mut dirnames := settings.dirnames

	for dirname in dirnames {
		if settings.parents {
			os.mkdir_all(dirname) or {
				eprintln('$app_name: $dirname: ' + err.msg())
				continue
			}
		} else {
			if os.exists(os.dir(dirname)) {
				os.mkdir(dirname) or {
					eprintln('$app_name: cannot create directory \'$dirname\': File exists ')
					continue
				}
			} else {
				eprintln('$app_name: cannot create directory \'$dirname\': No such file or directory ')
				continue
			}
		}
		if settings.verbose {
			println('$app_name: created directory \'$dirname\'')
		}
		os.chmod(dirname, settings.mode) or {
			// os.chmod(dirname,0o7777) or {

			eprintln('$app_name: $dirname: ' + err.msg())
		}
	}
}

///===================================================================///
///                                Args                               ///
///===================================================================///
fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	mode := fp.int('mode', `m`, 777, 'set file mode (as in chmod), not a=rwx - umask')
	parents := fp.bool('parents', `p`, false, 'no error if existing, make parent directories as needed')
	verbose := fp.bool('verbose', `v`, false, 'print a message for each created directory')

	dirnames := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}
	if dirnames.len == 0 {
		eprintln('$app_name: missing operand')
		eprintln("Try '$app_name --help' for more information.")
		exit(1)
	}
	return Settings{mode, parents, verbose, dirnames}
}
