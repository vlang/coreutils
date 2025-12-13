import os
import common

struct Directory {
	name string
mut:
	contents []string
}

fn go_print(file_list []Directory, seperator string) {
	mut constructed := ''
	if file_list.len == 1 {
		// Single directory
		for i, contents in file_list[0].contents {
			constructed += contents
			if i == file_list[0].contents.len - 1 {
				break
			}
			constructed += seperator
		}
	} else {
		// Multiple directories
		for i, dir in file_list {
			constructed += dir.name + ':\n'
			for j, contents in dir.contents {
				constructed += contents
				if j == dir.contents.len - 1 {
					break
				}
				constructed += seperator
			}
			if i != file_list.len - 1 {
				constructed += '\n\n'
			}
		}
	}
	print(constructed)
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('ls')
	fp.description('list directory contents')

	arg_1 := fp.bool('', `1`, false, 'list one file per line')
	arg_all := fp.bool('all', `a`, false, 'do not ignore entries starting with .')
	arg_almost_all := fp.bool('almost-all', `A`, false, 'do not list implied . and ..')
	arg_comma_seperated := fp.bool('comma-seperated', `m`, false, 'fill width with a comma seperated list of entries')
	arg_reverse := fp.bool('reverse', `r`, false, 'reverse order wile sorting')
	arg_help := fp.bool('help', 0, false, 'display this help and exit')

	// Get folders
	args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	// Help command
	if arg_help {
		println(fp.usage())
		exit(0)
	}

	// Get dir / dirs
	mut file_list := match args.len {
		0 {
			list := os.ls('.') or {
				eprintln(err)
				println("ls: cannot access '.': No such file or directory")
				exit(1)
			}

			[Directory{'.', list}]
		}
		else {
			// 1 or more dirs
			mut dirs := []Directory{}
			for arg in args {
				name := if args.len > 1 {
					arg
				} else {
					'.'
				}
				list := os.ls(arg) or {
					eprintln(err)
					println("ls: cannot access '" + arg + "': No such file or directory")
					exit(1)
				}
				dirs << Directory{name.replace('/', ''), list}
			}
			dirs
		}
	}

	// Define initial seperator
	mut seperator := '  '

	// Modify seperator
	if arg_comma_seperated {
		seperator = ', '
	}
	if arg_1 {
		seperator += '\n'
	}

	// Do not list dotfiles by default
	if !(arg_all || arg_almost_all) {
		for i, dir in file_list {
			file_list[i].contents = dir.contents.filter(fn (contents string) bool {
				return contents[0] != `.`
			})
		}
	}

	// . and .. path listing
	if arg_all {
		for i, _ in file_list {
			file_list[i].contents.prepend(['.', '..'])
		}
	}

	// Reverse
	if arg_reverse {
		for i, _ in file_list {
			file_list[i].contents.reverse_in_place()
		}
	}

	// Print
	go_print(file_list, seperator)
}
