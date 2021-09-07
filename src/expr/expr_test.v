import common.testing
import os

const the_executable = testing.prepare_executable('expr')

const cmd = testing.new_paired_command('expr', the_executable)

fn test_help_and_version() ? {
	cmd.ensure_help_and_version_options_work() ?
}

const tests = [
	r'5 + 6',
	r'5 - 6',
	r'5 \* 6',
	r'100 / 6',
	r'100 % 6',
	r'3 + -2',
	r'-2 + -2'
	// empty option is not supported for now
	//	r'-- -11 + 12',
	//	r'-11 + 12',
	//	r'-- -1 + 2',
	//	r'-1 + 2',
	//	r'-- -2 + 2',
	r'\( 100 % 6 \)',
	r'\( 100 % 6 \) - 8',
	r'9 / \( 100 % 6 \) - 8',
	r'9 / \( \( 100 % 6 \) - 8 \)',
	r'9 + \( 100 % 6 \)',
	r'00 \< 0!',
	r'00',
	r'-0'
	// make expr() return an optional
	//	r'0 \& 1 / 0',
	//	r'1 \| 1 / 0',
	// why does this have to return 0, not an empty string? I don't know
	//	r'"" \| ""',
	r'3 + -',
	r'-2417851639229258349412352 \< 2417851639229258349412352'
	// regex of vlib cannot process \\$
	//	r"'a\nb' : 'a\$'",
	// the tests below may fails due to the spec of regex in vlib
	r'"abc" : "a\\(b\\)c"',
	r'"a(" : "a("',
	r'_ : "a\\("',
	r'_ : "a\\(b"',
	r'"a(b" : "a(b"',
	r'"a)" : "a)"',
	r'_ : "a\\)"'
	//	r'_ : "\\)"',
	r'"ab" : "a\\(\\)b"',
	r'"a^b" : "a^b"',
	r'"a\$b" : "a\$b"',
	r'"" : "\\($\\)\\(^\\)"'
	//	r'"b" : "a*\\(^b\$\\)c*"',
	r'"X|" : "X\\(|\\)" : "(" "X|" : "X\\(|\\)" ")"'
	//	r'"X*" : "X\\(*\\)" : "(" "X*" : "X\\(*\\)" ")"',
	r'"abc" : "\\(\\)"'
	//	r'"{1}a" : "\\(\\{1\\}a\\)"',
	//	r'"X*" : "X\\(*\\)" : "^*"',
	r'"{1}" : "^\\{1\\}"',
	r'"{" : "{"'
	//	r'"abbcbd" : "a\\(b*\\)c\\1d"',
	//	r'"abbcbbbd" : "a\\(b*\\)c\\1d"',
	//	r'"abc" : "\\(.\\)\\1"',
	//	r'"abbccd" : "a\\(\\([bc]\\)\\2\\)*d"',
	//	r'"abbcbd" : "a\\(\\([bc]\\)\\2\\)*d"',
	//	r'"abbbd" : "a\\(\\(b\\)*\\2\\)*d"',
	//	r'"aabcd" : "\\(a\\)\\1bcd"',
	//	r'"aabcd" : "\\(a\\)\\1bc*d"',
	//	r'"aabd" : "\\(a\\)\\1bc*d"',
	//	r'"aabcccd" : "\\(a\\)\\1bc*d"',
	//	r'"aabcccd" : "\\(a\\)\\1bc*[ce]d"',
	//	r'"aabcccd" : "\\(a\\)\\1b\\(c\\)*cd\$"',
	//	r'"a*b" : "a\\(*\\)b"',
	//	r'"ab" : "a\\(**\\)b"',
	//	r'"ab" : "a\\(***\\)b"',
	r'"*a" : "*a"',
	r'"a" : "**a"'
	//	r'"a" : "***a"',
	r'"ab" : "a\\{1\\}b"',
	r'"ab" : "a\\{1,\\}b"',
	r'"aab" : "a\\{1,2\\}b"',
	r'_ : "a\\{1"',
	r'_ : "a\\{1a"',
	r'_ : "a\\{1a\\}"',
	r'"a" : "a\\{,2\\}"',
	r'"a" : "a\\{,\\}"',
	r'_ : "a\\{1,x\\}"',
	r'_ : "a\\{1,x"'
	//	r'_ : "a\\{32768\\}"',
	//	r'_ : "a\\{1,0\\}"',
	r'"acabc" : ".*ab\\{0,0\\}c"',
	r'"abcac" : "ab\\{0,1\\}c"',
	r'"abbcac" : "ab\\{0,3\\}c"',
	r'"abcac" : ".*ab\\{1,1\\}c"',
	r'"abcac" : ".*ab\\{1,3\\}c"',
	r'"abbcabc" : ".*ab\{2,2\}c"',
	r'"abbcabc" : ".*ab\{2,4\}c"'
	//	r'"aa" : "a\\{1\\}\\{1\\}"'
	//	r'"aa" : "a*\\{1\\}"',
	//	r'"aa" : "a\\{1\\}*"'
	//	r'"acd" : "a\\(b\\)?c\\1d"',
	r'"-5" : "-\\{0,1\\}[0-9]*\$"',
	r''
	// big number is not supported for now
	//	r'98782897298723498732987928734 + 1',
	//	r'98782897298723498732987928734 + 98782897298723498732987928735',
	//	r'98782897298723498732987928735 - 1',
	//	r'197565794597446997465975857469 - 98782897298723498732987928734',
	//	r"98782897298723498732987928735 '*' 98782897298723498732987928734",
	//	r'9758060798730154302876482828124348356960410232492450771490 / 98782897298723498732987928734',
	r'9 9',
	r'2 a',
	r"2 '+'",
	r'2 :',
	r'length',
	r"'(' 2 ",
	r"'(' 2 a",
]

fn test_results() ? {
	mut failed := []string{}
	for test in tests {
		res := cmd.same_results(test)
		if !res {
			if os.execute('$cmd.original $test').exit_code == 2
				&& os.execute('$cmd.deputy $test').exit_code == 2 {
				continue
			}
			failed << test
		}
	}
	println(failed.join('\n'))
	assert failed.len == 0
}

const mb_tests = [
	'length abcdef',
	'length \u03B1bcdef',
	'length abc\u03B4ef',
	'length fedcb\u03B1',
	'length \xB1aaa',
	'length aaa\xCE',
	'length \u1F14\u03BA\u03C6\u03C1\u03B1\u03C3\u03B9\u03C2',
	'index abcdef fb',
	'index \u03B1bc\u03B4ef b',
	'index \u03B1bc\u03B4ef f',
	'index \u03B1bc\u03B4ef \u03B4',
	'index \xCEbc\u03B4ef \u03B4',
	'index \u03B1bc\u03B4ef \xB4',
	'index \u03B1bc\xB4ef \xB4',
	'substr abcdef 2 3',
	'substr \u03B1bc\u03B4ef 1 1',
	'substr \u03B1bc\u03B4ef 3 2',
	'substr \u03B1bc\u03B4ef 4 1',
	'substr \u03B1bc\u03B4ef 4 2',
	'substr \u03B1bc\u03B4ef 6 1',
	'substr \u03B1bc\u03B4ef 7 1'
	// fail: multi; broken UTF-8 is treated in different way
	//	"substr \u03B1bc\xB4ef 3 3",
	'match abcdef ab',
	'match abcdef "\\(ab\\)"'
	// fail: single; this is a good news, regex in vlib supports UTF-8
	//	"match \u03B1bc\u03B4ef .bc",
	// fail: both; broken regex of vlib, see #10885
	//	"match \u03B1bc\u03B4ef ..bc",
	// fail: single; this is a good news, regex in vlib supports UTF-8
	//	"match \u03B1bc\u03B4ef '\\(.b\\)c'",
	// fail: multi; broken UTF-8 is treated in different way
	//	"match \xCEbc\u03B4ef '\\(.\\)'",
	// fail: single; this is a good news, regex in vlib supports UTF-8
	//	"match \u03B1bc\u03B4e '\\([\u03B1]\\)'",
]

fn test_multi_byte_results() ? {
	mut failed := []string{}
	for test in mb_tests {
		res := cmd.same_results(test)
		if !res {
			if os.execute('$cmd.original $test').exit_code == 2
				&& os.execute('$cmd.deputy $test').exit_code == 2 {
				continue
			}
			failed << test
		}
	}
	println(failed.join('\n'))
	assert failed.len == 0
}
