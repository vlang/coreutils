import os
import common
import flag

const app_name = 'numfmt'
const scales = ['none', 'auto', 'si', 'iec', 'iec-i']
const rounds = ['up', 'down', 'from-zero', 'towards-zero', 'nearest']
const invalids = ['abort', 'fail', 'warn', 'ignore']

struct Options {
	delimiter string = ' '
	fields    []int  = [1]
	from_unit int    = 1
	grouping  bool
	header    int
	invalid   string
	numbers   []string
	padding   int
	pformat   string
	round     string = 'from-zero'
	suffix    string
	to        string = 'none'
	to_unit   int    = 1
}

fn get_options() Options {
	mut fp := flag.new_flag_parser(os.args)

	fp.application(app_name)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.arguments_description('[NUMBER]...')
	fp.description('\n
		Convert numbers from/to human-readable strings

		Reformat NUMBER(s), or the numbers from standard input if none
		are specified.'.trim_indent())

	delimiter := fp.string('delimiter', `d`, ' ', 'use <string> instead of whitespace for delimiter')
	fields := fp.int_multi('fields', 0, 'replace the numbers in these input fields (default=1)')
	pformat := fp.string('format', 0, '', 'use printf style floating-point <string>')
	from_unit := fp.int('from-unit', 0, 1, 'specify the input unit size (instead of the default 1)')
	grouping := fp.bool('grouping', 0, false, 'use locale-defined grouping of digits, e.g. 1,000,000')
	header := fp.int('header', 0, 1,
		'print (without converting) the first N header lines; <int>\n${flag.space}' +
		'defaults to 1 if not specified')
	invalid := fp.string('invalid', 0, 'abort',
		'failure mode for invalid numbers: MODE can be:\n${flag.space}' +
		'abort (default), fail, warn, ignore')
	padding := fp.int('padding', 0, 0,
		'pad the output to N characters; positive N will\n${flag.space}' +
		'right-align; negative N will left-align; padding is\n${flag.space}' +
		'ignored if the output is wider than N; the default is to\n${flag.space}' +
		'automatically pad if a whitespace is found')
	round := fp.string('round', 0, 'from-zero',
		'use METHOD for rounding when scaling; METHOD can be:\n${flag.space}' +
		'up, down, from-zero (default), towards-zero, nearest')
	suffix := fp.string('suffix', 0, '',
		'add SUFFIX to output numbers, and accept optional SUFFIX\n${flag.space}' +
		'in input numbers')
	to := fp.string('to', 0, 'none', 'auto-scale output numbers to UNIT\n${flag.space}' +
		'none, si, iec, iec-i')
	to_unit := fp.int('to-unit', 0, 1, 'the output unit size (instead of the default 1)')
	fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline\n')

	fp.footer("\n
		UNIT options:
		  none	no auto-scaling is done; suffixes will trigger an error

		  auto	accept optional single/two letter suffix:
			1K = 1000, 1k = 1000, 1Ki = 1024, 1M = 1000000, 1Mi =
			1048576,

		  si	accept optional single letter suffix:
			1k = 1000, 1K = 1000, 1M = 1000000, ...

		  iec	accept optional single letter suffix:
			1K = 1024, 1k = 1024, 1M = 1048576, ...

		  iec-i	accept optional two-letter suffix:
			1Ki = 1024, 1ki = 1024, 1Mi = 1048576, ...

		FIELDS supports cut(1) style field ranges:
		  N	N'th field, counted from 1

		  N-	from N'th field, to end of line

		  N-M	from N'th to M'th field (inclusive)

		  -M	from first to M'th field (inclusive)

		  -	all fields

			Multiple fields/ranges can be separated with commas

		FORMAT must be suitable for printing one floating-point argument
		'%f'.  Optional quote (%'f) will enable --grouping (if supported
		by current locale).  Optional width value (%10f) will pad output.
		Optional zero (%010f) width will zero pad the number. Optional
		negative values (%-10f) will left align.  Optional precision
		(%.1f) will override the input determined precision.

		Exit status is 0 if all input numbers were successfully
		converted.  By default, numfmt will stop at the first conversion
		error with exit status 2.  With --invalid='fail' a warning is
		printed for each conversion error and the exit status is 2.  With
		--invalid='warn' each conversion error is diagnosed, but the exit
		status is 0.  With --invalid='ignore' conversion errors are not
		diagnosed and the exit status is 0."
		.trim_indent())

	fp.footer(common.coreutils_footer())
	numbers := fp.finalize() or { exit_error(err.msg()) }

	if invalid !in invalids {
		exit_error('unrecognized invalid option ${invalid}')
	}

	if to !in scales {
		exit_error('unrecognized scale option ${to}')
	}

	if round !in rounds {
		exit_error('unrecognized rounding option ${round}')
	}

	return Options{
		delimiter: delimiter
		fields:    if fields == [] { [1] } else { fields }
		from_unit: from_unit
		grouping:  grouping
		header:    header
		invalid:   invalid
		numbers:   numbers
		padding:   padding
		pformat:   pformat
		round:     round
		suffix:    suffix
		to:        to
		to_unit:   to_unit
	}
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
