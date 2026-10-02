import common
import os

const app_name = 'sort'

// CheckMode is what -c and -C ask for.
enum CheckMode {
	none
	diagnose
	quiet
}

struct Options {
mut:
	ordering        Ordering
	key_specs       []string
	check           CheckMode
	unique          bool
	merge           bool
	output          string
	separator       string
	has_separator   bool
	zero_terminated bool
	debug           bool
	files           []string
	files0_from     string
}

// long options that take a value
const long_value_options = ['key', 'field-separator', 'output', 'sort', 'files0-from', 'buffer-size',
	'temporary-directory', 'parallel', 'batch-size', 'compress-program', 'random-source']

// short options that take a value
const short_value_options = 'kto'

fn get_options() (Options, []SortKey) {
	mut o := Options{}
	mut args := []string{}
	for a in os.args[1..] {
		args << a
	}
	mut i := 0
	mut no_more_options := false

	for i < args.len {
		arg := args[i]
		i++
		if no_more_options || arg == '-' || !arg.starts_with('-') {
			o.files << arg
			continue
		}
		if arg == '--' {
			no_more_options = true
			continue
		}
		if arg.starts_with('--') {
			i = parse_long_option(mut o, arg[2..], args, i)
			continue
		}
		i = parse_short_options(mut o, arg[1..], args, i)
	}

	// GNU's default separator is the transition from non-blank to blank.
	if !o.has_separator {
		o.separator = ' '
	}
	return o, parse_keys(o.key_specs, o.ordering)
}

// sort_options is the ordering the sort itself runs under. -u keeps the first line
// of a run of equal keys, and which line that is comes from the order the lines
// arrived in, so -u orders stably even though -s was not given. The check modes
// do not take this, because there -u means that an equal line is a disorder.
fn sort_options(options Options) Options {
	if options.unique && !options.ordering.stable {
		mut out := options
		out.ordering.stable = true
		return out
	}
	return options
}

// take_value returns the value of an option, which may be attached to it, along
// with the index of the next argument. A short option with no value gets the
// message GNU uses, a long one its own.
fn take_value(name string, long_form bool, rest string, args []string, i int) (string, int) {
	if rest.len > 0 {
		return rest, i
	}
	if i < args.len {
		return args[i], i + 1
	}
	if long_form {
		option_error("option '${app_name} --${name}' requires an argument")
	} else {
		option_error("option requires an argument -- '${name}'")
	}
	return '', i
}

fn parse_long_option(mut o Options, arg string, args []string, start_i int) int {
	mut i := start_i
	mut name := arg
	mut value := ''
	mut has_value := false
	if eq := arg.index('=') {
		name = arg[..eq]
		value = arg[eq + 1..]
		has_value = true
	}

	needs_value := name in long_value_options
	if needs_value && !has_value {
		mut taken := ''
		taken, i = take_value(name, true, '', args, i)
		value = taken
	}

	match name {
		'help' {
			print_help()
			exit(0)
		}
		'version' {
			// The test rig checks for this exact shape, so the version goes through
			// the shared helper rather than being spelled out here.
			println('${app_name} ${common.coreutils_version()}')
			exit(0)
		}
		'ignore-leading-blanks' { o.ordering.ignore_blanks = true }
		'dictionary-order' { o.ordering.dictionary = true }
		'ignore-case' { o.ordering.fold_case = true }
		'ignore-nonprinting', 'ignore-non-printing' { o.ordering.ignore_nonprint = true }
		'reverse' { o.ordering.reverse = true }
		'stable' { o.ordering.stable = true }
		'merge' { o.merge = true }
		'unique' { o.unique = true }
		'debug' { o.debug = true }
		'zero-terminated' { o.zero_terminated = true }
		'numeric-sort' { o.ordering.mode = .numeric }
		'general-numeric-sort' { o.ordering.mode = .general }
		'human-numeric-sort' { o.ordering.mode = .human }
		'month-sort' { o.ordering.mode = .month }
		'version-sort' { o.ordering.mode = .version }
		'random-sort' { o.ordering.random = true }
		'sort' {
			if value in ['general-numeric', 'human-numeric', 'month', 'numeric', 'random', 'version'] {
				o.ordering.mode = sort_word(value)
			} else {
				option_error("invalid argument '${value}' for --sort")
			}
			if value == 'random' {
				o.ordering.random = true
			}
		}
		'key' { o.key_specs << value }
		'field-separator' { set_separator(mut o, value) }
		'output' { o.output = value }
		'files0-from' { o.files0_from = value }
		'buffer-size', 'temporary-directory', 'parallel', 'batch-size',
		'compress-program', 'random-source' {
		}
		'check' {
			match value {
				'' { o.check = .diagnose }
				'diagnose-first' { o.check = .diagnose }
				'quiet', 'silent' { o.check = .quiet }
				else { error_only("invalid argument '${value}' for '--check'") }
			}
		}
		else {
			option_error("unrecognized option '--${name}'")
		}
	}
	return i
}

// parse_short_options walks a bundle of short options such as -rn, where one of
// them may take the rest of the bundle as its value.
fn parse_short_options(mut o Options, arg string, args []string, start_i int) int {
	mut i := start_i
	mut c := 0
	for c < arg.len {
		letter := arg[c]
		c++
		if in_bytes(short_value_options, letter) {
			rest := arg[c..]
			mut value := ''
			value, i = take_value(short_name(letter), false, rest, args, i)
			apply_short_with_value(mut o, letter, value)
			return i
		}
		apply_short(mut o, letter)
	}
	return i
}

// short_name spells a short option letter for a message.
// short_name spells one short option letter for a message.
fn short_name(letter u8) string {
	mut out := []u8{}
	out << letter
	return out.bytestr()
}

fn in_bytes(set string, c u8) bool {
	for x in set {
		if x == c {
			return true
		}
	}
	return false
}

fn in_string(set []string, needle string) bool {
	for s in set {
		if s == needle {
			return true
		}
	}
	return false
}

fn apply_short(mut o Options, letter u8) {
	match letter {
		`b` { o.ordering.ignore_blanks = true }
		`d` { o.ordering.dictionary = true }
		`f` { o.ordering.fold_case = true }
		`i` { o.ordering.ignore_nonprint = true }
		`r` { o.ordering.reverse = true }
		`s` { o.ordering.stable = true }
		`m` { o.merge = true }
		`u` { o.unique = true }
		`c` { o.check = .diagnose }
		`C` { o.check = .quiet }
		`z` { o.zero_terminated = true }
		`n` { o.ordering.mode = .numeric }
		`g` { o.ordering.mode = .general }
		`h` { o.ordering.mode = .human }
		`M` { o.ordering.mode = .month }
		`V` { o.ordering.mode = .version }
		`R` { o.ordering.random = true }
		else {
			option_error("invalid option -- '${letter.str()}'")
		}
	}
}

fn apply_short_with_value(mut o Options, letter u8, value string) {
	match letter {
		`k` { o.key_specs << value }
		`t` { set_separator(mut o, value) }
		`o` { o.output = value }
		else { option_error("invalid option -- '${letter.str()}'") }
	}
}

// set_separator applies -t. GNU takes the rest of the option argument, or the
// next argument if that is empty, and refuses anything longer than one character.
// This message gets no advice about --help.
fn set_separator(mut o Options, value string) {
	if value.len != 1 {
		error_only("multi-character tab '${value}'")
	}
	o.separator = value
	o.has_separator = true
}

// sort_word maps a --sort argument onto a mode. An unknown word is rejected by the
// caller, since only it can say which option the word came from.
fn sort_word(word string) OrderMode {
	mode := match word {
		'general-numeric' { OrderMode.general }
		'human-numeric' { OrderMode.human }
		'month' { OrderMode.month }
		'numeric' { OrderMode.numeric }
		'random' {
			// --sort=random only sets the mode; the shuffling needs -R, which the
			// caller of this function turns on through the same option.
			OrderMode.ascii
		}
		'version' { OrderMode.version }
		else { OrderMode.ascii }
	}
	return mode
}

// option_error reports a bad option, a bad argument or a missing value the way GNU
// does, and ends the program with the status GNU uses for those.
@[noreturn]
fn option_error(message string) {
	eprintln('${app_name}: ${message}')
	eprintln("Try '${app_name} --help' for more information.")
	exit(2)
}

// error_only reports a bad argument that GNU does not follow with the advice
// about --help, which is the case for a bad key and a bad --check argument.
@[noreturn]
fn error_only(message string) {
	eprintln('${app_name}: ${message}')
	exit(2)
}

fn print_help() {
	println('Usage: ${app_name} [OPTION]... [FILE]...')
	println('  or:  ${app_name} [OPTION]... --files0-from=F')
	println('Write sorted concatenation of all FILE(s) to standard output.')
	println('')
	println('With no FILE, or when FILE is -, read standard input.')
	println('')
	println('Mandatory arguments to long options are mandatory for short options too.')
	println('Ordering options:')
	println('')
	println('  -b, --ignore-leading-blanks  ignore leading blanks')
	println('  -d, --dictionary-order      consider only blanks and alphanumeric characters')
	println('  -f, --ignore-case           fold lower case to upper case characters')
	println('  -g, --general-numeric-sort  compare according to general numerical value')
	println('  -i, --ignore-nonprinting    consider only printable characters')
	println("  -M, --month-sort            compare (unknown) < 'JAN' < ... < 'DEC'")
	println('  -h, --human-numeric-sort    compare human readable numbers (e.g., 2K 1G)')
	println('  -n, --numeric-sort          compare according to string numerical value;')
	println('                                see full documentation for supported strings')
	println('  -R, --random-sort           shuffle, but group identical keys.  See shuf(1)')
	println('      --random-source=FILE    get random bytes from FILE')
	println('  -r, --reverse               reverse the result of comparisons')
	println('      --sort=WORD             sort according to WORD:')
	println('                                general-numeric -g, human-numeric -h, month -M,')
	println('                                numeric -n, random -R, version -V')
	println('  -V, --version-sort          natural sort of (version) numbers within text')
	println('')
	println('Other options:')
	println('')
	println('      --batch-size=NMERGE   merge at most NMERGE inputs at once;')
	println('                            for more use temp files')
	println('  -c, --check, --check=diagnose-first  check for sorted input; do not sort')
	println('  -C, --check=quiet, --check=silent  like -c, but do not report first bad line')
	println('      --compress-program=PROG  compress temporaries with PROG;')
	println('                              decompress them with PROG -d')
	println('      --debug               annotate the part of the line used to sort, and')
	println('                              warn about questionable usage to standard error')
	println('      --files0-from=F       read input from the files specified by')
	println('                            NUL-terminated names in file F;')
	println('                            If F is - then read names from standard input')
	println('  -k, --key=KEYDEF          sort via a key; KEYDEF gives location and type')
	println('  -m, --merge               merge already sorted files; do not sort')
	println('  -o, --output=FILE         write result to FILE instead of standard output')
	println('  -s, --stable              stabilize sort by disabling last-resort comparison')
	println('  -S, --buffer-size=SIZE    use SIZE for main memory buffer')
	println('  -t, --field-separator=SEP  use SEP instead of non-blank to blank transition')
	println('  -T, --temporary-directory=DIR  use DIR for temporaries, not $TMPDIR or /tmp;')
	println('                              multiple options specify multiple directories')
	println('      --parallel=N          change the number of sorts run concurrently to N')
	println('  -u, --unique              output only the first of lines with equal keys;')
	println('                              with -c, check for strict ordering')
	println('  -z, --zero-terminated     line delimiter is NUL, not newline')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
	println('')
	println('KEYDEF is F[.C][OPTS][,F[.C][OPTS]] for start and stop position, where F is a')
	println('field number and C a character position in the field; both are origin 1, and')
	println("the stop position defaults to the line's end.  If neither -t nor -b is in")
	println('effect, characters in a field are counted from the beginning of the preceding')
	println('whitespace.  OPTS is one or more single-letter ordering options [bdfgiMhnRrV],')
	println('which override global ordering options for that key.  If no key is given, use')
	println('the entire line as the key.  Use --debug to diagnose incorrect key usage.')
	println('')
	println(common.coreutils_footer())
}
