import common
import os
import readline

const app_name = 'tr'
const app_description = 'Translate one set of characters into another set of characters'

// Entry point
// Usage: ./hostname: Get the host name
// Usage: ./hostname <name>: Set the hostname as 'name'
fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	is_complement := fp.bool('complement', `c`, false, 'Enable complement mode')
	is_delete := fp.bool('delete', `d`, false, 'Enable delete mode')
	is_squeeze := fp.bool('squeeze-repeats', `s`, false, 'Enable squeeze mode')
	is_truncate := fp.bool('truncate-set1', `t`, false, 'Enable truncate mode')

	fp.usage_example('a f')
	fp.usage_example('-c a f')
	fp.usage_example('-d a')
	fp.usage_example('-s a f')
	fp.usage_example('-t a f')

	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	// Other flags
	// fp.remaining_parameters()

	if is_complement {
		if additional_args.len != 2 {
			common.exit_with_error_message(app_name, 'When in complement mode, two arguments is expected')
		}
		translate_complement(additional_args)!
	} else if is_delete {
		if additional_args.len != 1 {
			common.exit_with_error_message(app_name, 'When in delete mode, one argument is expected')
		}
		translate_delete(additional_args)!
	} else if is_squeeze {
		if additional_args.len != 2 {
			common.exit_with_error_message(app_name, 'When in squeeze mode, two arguments is expected')
		}
		translate_squeeze(additional_args)!
	} else if is_truncate {
		if additional_args.len != 2 {
			common.exit_with_error_message(app_name, 'When in truncate mode, two arguments is expected')
		}
		translate_truncate(additional_args)!
	} else {
		if additional_args.len != 2 {
			common.exit_with_error_message(app_name, 'Expected two arguments')
		}
		translate_normal(additional_args)!
	}
}

// When no boolean flag is given
// example:
//   tr a f
fn translate_normal(args []string) ! {
	mut r := readline.Readline{}
	mut character_map := map[rune]rune{}
	for idx, character in args[0].runes() {
		character_map[character] = args[1].runes()[idx] or { ''.u8() }
	}
	print(character_map)

	for {
		line := r.read_line_utf8('')!
		for letter in line {
			print(character_map[letter] or { letter })
		}
		println('')
	}
}

// When -c, -C or --complement is given
// example:
//   tr -c a f
fn translate_complement(args []string) ! {
	mut r := readline.Readline{}
	mut character_map := map[rune]rune{}
	for idx, character in args[0].runes() {
		character_map[character] = args[1].runes()[idx] or { ''.u8() }
	}

	for {
		line := r.read_line_utf8('')!
		for letter in line {
			print(character_map[letter] or { letter })
		}
		println('')
	}
}

// When -d or --delete is given
// example:
//   tr -d a
fn translate_delete(args []string) ! {
	mut r := readline.Readline{}
	mut character_map := map[rune]rune{}
	for character in args[0].runes() {
		character_map[character] = ''.u8()
	}

	for {
		line := r.read_line_utf8('')!
		for letter in line {
			print(character_map[letter] or { letter })
		}
		println('')
	}
}

// When -s or --squeeze-repeats is given
// example:
//   tr -s a bcdef
fn translate_squeeze(args []string) ! {
	mut r := readline.Readline{}
	mut character_map := map[rune]rune{}
	for idx, character in args[0].runes() {
		character_map[character] = args[1].runes()[idx] or { ''.u8() }
	}

	for {
		line := r.read_line_utf8('')!
		for letter in line {
			print(character_map[letter] or { letter })
		}
		println('')
	}
}

// When -t or --truncate-set1 is given
// example:
//   tr -t abcd ab
fn translate_truncate(args []string) ! {
	mut r := readline.Readline{}
	mut character_map := map[rune]rune{}
	for idx, character in args[0].runes() {
		character_map[character] = args[1].runes()[idx] or { ''.u8() }
	}

	for {
		line := r.read_line_utf8('')!
		for letter in line {
			print(character_map[letter] or { letter })
		}
		println('')
	}
}
