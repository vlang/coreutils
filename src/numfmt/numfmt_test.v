module main

fn test_split_parts() {
	mut num, mut suffix := split_parts('22')
	assert num == '22'
	assert suffix == ''

	num, suffix = split_parts('2.1K')
	assert num == '2.1'
	assert suffix == 'K'

	num, suffix = split_parts('-1,100.0001')
	assert num == '-1,100.0001'
	assert suffix == ''

	num, suffix = split_parts('-1,100.0001GB')
	assert num == '-1,100.0001'
	assert suffix == 'GB'

	num, suffix = split_parts('KB1000')
	assert num == ''
	assert suffix == 'KB1000'
}

fn test_number_grouping() {
	assert commaize(200.0) == '200'
	assert commaize(2000.0) == '2,000'
	assert commaize(-200_000.0) == '-200,000'
	assert commaize(-2_000_000.0) == '-2,000,000'
}

fn test_numfmt() {
	mut app := App{}
	assert numfmt('2K', mut app, Options{}) or { '' } == '2000'
	assert numfmt('-2M', mut app, Options{}) or { '' } == '-2000000'
	assert numfmt('-2.0M', mut app, Options{ grouping: true }) or { '' } == '-2,000,000'
	assert numfmt('20G', mut app, Options{}) or { '' } == '20000000000'
	assert numfmt('20G', mut app, Options{ grouping: true }) or { '' } == '20,000,000,000'
}

fn test_fields() {
	mut app := App{}
	assert do_numfmt(['Field', '1000', '2000'], mut app, Options{ fields: [2, 3] }) == 'Field 1000 2000'
	assert do_numfmt(['Field', '1000', '2000'], mut app, Options{ fields: [2, 3], grouping: true }) == 'Field 1,000 2,000'
}

// The expectations below were read off GNU 9.4 one at a time, since SI suffixes
// are upper case there and this port used to answer in lower case, and since
// --to=none hands the number back as it is rather than rounding it.
//
//	--to=si 200000        200K		(used to be 200k)
//	--to=si 2000000       2.0M		(used to be 2.0m)
//	--to=si 200000.1      201K		(used to be 201k)
//	--to=si 2000000.2     2.1M		(used to be 2.1m)
//	--to=none 2000000.6   2000000.6	(used to be 2000001)
//
// The suffix-in-the-input cases are this port's own behaviour and not GNU's:
// GNU rejects `numfmt 2K` with "rejecting suffix in input" unless --from is
// given, and this port has no --from. They are kept as they are, as a record of
// what it does instead of pretending it agrees.
fn test_to_options() {
	mut app := App{}
	assert numfmt('200000', mut app, Options{ to: 'si' }) or { '' } == '200K'
	assert numfmt('2000000', mut app, Options{ to: 'si' }) or { '' } == '2.0M'
	assert numfmt('200000', mut app, Options{ to: 'iec' }) or { '' } == '196K'
	assert numfmt('2000000', mut app, Options{ to: 'iec' }) or { '' } == '2.0M'
	assert numfmt('200000', mut app, Options{ to: 'iec-i' }) or { '' } == '196Ki'
	assert numfmt('2000000', mut app, Options{ to: 'iec-i' }) or { '' } == '2.0Mi'
	assert numfmt('2000000', mut app, Options{ to: 'none' }) or { '' } == '2000000'

	assert numfmt('200000.1', mut app, Options{ to: 'si' }) or { '' } == '201K'
	assert numfmt('2000000.2', mut app, Options{ to: 'si' }) or { '' } == '2.1M'
	assert numfmt('200000.3', mut app, Options{ to: 'iec' }) or { '' } == '196K'
	assert numfmt('2000000.4', mut app, Options{ to: 'iec' }) or { '' } == '2.0M'
	assert numfmt('200000.3', mut app, Options{ to: 'iec-i' }) or { '' } == '196Ki'
	assert numfmt('2000000.6', mut app, Options{ to: 'iec-i' }) or { '' } == '2.0Mi'
	assert numfmt('2000000.6', mut app, Options{ to: 'none' }) or { '' } == '2000000.6'
}
