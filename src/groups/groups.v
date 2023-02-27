import os
import common
import encoding.csv

const (
	tool_name  = 'groups'
	group_file = '/etc/group'
)

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(tool_name)
	fp.description('Show which groups a user belongs to')
	fp.arguments_description('[user]')
	fp.limit_free_args(0, 1)!
	mut args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	mut input := ''

	if args == [] {
		input = os.loginname() or { '' }
	} else {
		input = args.join(' ')
	}

	mut ret := []string{}
	raw_data := os.read_file(group_file)! // v does not have a dedicated func for finding groups *yet*
	mut parser := csv.new_reader(raw_data, delimiter: `:`)

	for {
		line := parser.read() or { break }
		if line.len == 4 {
			if line[3].contains(input) {
				ret << line[0]
			}
		} else if line.len > 4 || line.len < 3 {
			common.exit_with_error_message(tool_name, '${group_file} is formatted incorrectly')
		}
	}

	if args != [] {
		print('${input}: ')
	}
	println(ret.join(' '))
}
