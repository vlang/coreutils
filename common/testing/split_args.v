module testing

import os

// split_args breaks a command line into the argument array os.exec takes.
//
// It exists because os.execute is deprecated and `make test` builds with -W, where a
// deprecation is an error: on current V that stopped 31 of the 49 test files from
// compiling at all. Every command in this repository is written as a string by the
// tests, so the string has to be split somewhere, and this is that place.
//
// The rules are the ones those strings actually use, which is not all of a shell:
//
//   tool -a "two words" 'and more'      three kinds of quoting, all of them in use
//   tool --delimiter="|"                a quoted value with a character in it
//   sh -c "exit 42"                     a quoted argument containing a space
//   tr -d '\r'                          a backslash inside single quotes
//   C:\Users\me\file.txt                a backslash outside quotes, which is a path
//
// So: whitespace between words, single and double quotes, and nothing else. A
// backslash is an ordinary character everywhere, because on this platform it is
// almost always part of a path, and a shell's rule of eating it would take the
// volume off. An unterminated quote is not an error here: the rest of the line
// becomes one word, so a test fails on what the program said rather than on a parse
// in this file.
pub fn split_args(cmd string) []string {
	mut args := []string{}
	mut word := []rune{}
	mut in_word := false
	mut quote := u8(0)
	for ch in cmd.runes() {
		c := u8(ch)
		if quote != 0 {
			if c == quote {
				quote = 0
			} else {
				word << ch
			}
			continue
		}
		if c == `'` || c == `"` {
			quote = c
			in_word = true
			continue
		}
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` {
			if in_word {
				args << word.string()
				word = []rune{}
				in_word = false
			}
			continue
		}
		word << ch
		in_word = true
	}
	if in_word {
		args << word.string()
	}
	return args
}

// run_args is split_args for the common case where the caller has the executable and
// the rest of the command line already separate, which is how the tests below read.
pub fn run_args(exe string, args string) os.Result {
	return os.exec(split_args('${exe} ${args}'))
}
