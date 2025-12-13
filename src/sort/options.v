import common
import flag
import os
import time

const app_name = 'sort'

struct Options {
	ignore_leading_blanks bool
	dictionary_order      bool
	ignore_case           bool
	ignore_non_printing   bool
	numeric               bool
	reverse               bool
	// other optoins
	check_diagnose  bool
	check_quiet     bool
	sort_keys       []string
	field_separator string = ' '
	merge           bool
	output_file     string
	unique          bool
	files           []string
}

fn get_options() Options {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.arguments_description('[FILE]')
	fp.description('\nWrite sorted concatenation of all FILE(s) to standard output.' +
		'\nWith no FILE, or when FILE is -, read standard input.')

	ignore_leading_blanks := fp.bool('ignore-leading-blanks', `b`, false, 'ignore leading blanks')
	dictionary_order := fp.bool('dictionary-order', `d`, false, 'consider only blanks and alphanumeric characters')
	ignore_case := fp.bool('ignore-case', `f`, false, 'fold lower case to upper case characters')
	ignore_non_printing := fp.bool('ignore-non-printing', `i`, false, 'consider only printable characters')
	numeric := fp.bool('numeric-sort', `n`, false,
		'Restrict the sort key to an initial numeric\n${flag.space}' +
		'string, consisting of optional <blank> characters,\n${flag.space}' +
		'optional <hyphen-minus> character, and zero or\n${flag.space}' +
		'more digits, which shall be sorted by arithmetic\n${flag.space}' +
		'value. An empty digit string shall be treated as\n${flag.space}' +
		'zero. Leading zeros shall not affect ordering.')
	reverse := fp.bool('reverse', `r`, false, 'reverse the result of comparisons\n\nOther options:')

	check_diagnose := fp.bool('', `c`, false, 'check for sorted input; do not sort')
	check_quiet := fp.bool('', `C`, false, 'like -c, but do not report first bad line')
	sort_keys := fp.string_multi('key', `k`, 'sort via a key(s); <string> gives location and type')
	merge := fp.bool('merge', `m`, false, 'merge already sorted files; do not sort')
	field_separator := fp.string('', `t`, ' ', 'use <string> as field separator')
	output_file := fp.string('output', `o`, '', 'write result to FILE instead of standard output')
	unique := fp.bool('unique', `u`, false, 'with -c, check for strict ordering;\n${flag.space}' +
		'without -c, output only the first of an equal run')

	fp.footer("

		KEYDEF is F[.C][OPTS][,F[.C][OPTS]] for start and stop position,
		where F is a field number and C a character position in the
		field; both are origin 1, and the stop position defaults to the
		line's end.  If neither -t nor -b is in effect, characters in a
		field are counted from the beginning of the preceding whitespace.
		OPTS is one or more single-letter ordering options [bdfir], which
		override global ordering options for that key. If no key is
		given, use the entire line as the key.".trim_indent())

	fp.footer(common.coreutils_footer())
	files := fp.finalize() or { exit_error(err.msg()) }

	return Options{
		ignore_leading_blanks: ignore_leading_blanks
		dictionary_order:      dictionary_order
		ignore_case:           ignore_case
		ignore_non_printing:   ignore_non_printing
		numeric:               numeric
		reverse:               reverse
		// other options
		check_diagnose:  check_diagnose
		check_quiet:     check_quiet
		sort_keys:       sort_keys
		field_separator: field_separator
		merge:           merge
		output_file:     output_file
		unique:          unique
		files:           scan_files_arg(files)
	}
}

fn scan_files_arg(files_arg []string) []string {
	mut files := []string{}
	for file in files_arg {
		if file == '-' {
			files << stdin_to_tmp()
			continue
		}
		files << file
	}
	if files.len == 0 {
		files << stdin_to_tmp()
	}
	return files
}

const tmp_pattern = '/${app_name}-tmp-'

fn stdin_to_tmp() string {
	tmp := '${os.temp_dir()}/${tmp_pattern}${time.ticks()}'
	os.create(tmp) or { exit_error(err.msg()) }
	mut f := os.open_append(tmp) or { exit_error(err.msg()) }
	defer { f.close() }
	for {
		s := os.get_raw_line()
		if s.len == 0 {
			break
		}
		f.write_string(s) or { exit_error(err.msg()) }
	}
	return tmp
}

@[noreturn]
fn exit_error(msg string) {
	if msg.len > 0 {
		eprintln('${app_name}: ${error}')
	}
	eprintln("Try '${app_name} --help' for more information.")
	exit(2) // exit(1) is used with the -c option
}
