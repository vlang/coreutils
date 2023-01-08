import os
import common
import encoding.csv

const (
	tool_name = 'groups'
)

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('groups')
	fp.description('Show which groups a user belongs to')
	fp.limit_free_args(0, 1)!
	mut input := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	if input == [] {
		input = [os.loginname()]
	}

	mut ret := map[string][]string{}

	config := csv.ReaderConfig{`:`, `#`} // no disabling comments?
	data := os.read_file('/etc/group') or {
		common.exit_with_error_message(tool_name, 'cannot read /etc/groups: ${err}')
	}
	mut parser := csv.new_reader(data, config)

	// this is sort of spagetti
	// takes a line, checks if its syntax is correct
	// then splits it up, and each user is added to the map ret
	// then when it comes time to get the users groups
	// just look it up in the map
	for i := 1; true; i++ {
		line := parser.read() or { break }

		if line.len == 4 {
			users := line[3].split(',') // split users in group line[0] into array
			for user in users { // loop through, add them to map
				ret[user] << line[0]
			}
		} else if line.len > 4 || line.len < 3 {
			common.exit_with_error_message(tool_name, '/etc/groups is incorectly formatted on line ${i}')
		}
	}

	println(ret[input[0]].join(' '))
}
