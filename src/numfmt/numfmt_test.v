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

fn test_to_options() {
	mut app := App{}
	assert numfmt('200000', mut app, Options{ to: 'si' }) or { '' } == '200k'
	assert numfmt('2000000', mut app, Options{ to: 'si' }) or { '' } == '2.0m'
	assert numfmt('200000', mut app, Options{ to: 'iec' }) or { '' } == '196K'
	assert numfmt('2000000', mut app, Options{ to: 'iec' }) or { '' } == '2.0M'
	assert numfmt('200000', mut app, Options{ to: 'iec-i' }) or { '' } == '196Ki'
	assert numfmt('2000000', mut app, Options{ to: 'iec-i' }) or { '' } == '2.0Mi'
	assert numfmt('2000000', mut app, Options{ to: 'none' }) or { '' } == '2000000'

	assert numfmt('200000.1', mut app, Options{ to: 'si' }) or { '' } == '201k'
	assert numfmt('2000000.2', mut app, Options{ to: 'si' }) or { '' } == '2.1m'
	assert numfmt('200000.3', mut app, Options{ to: 'iec' }) or { '' } == '196K'
	assert numfmt('2000000.4', mut app, Options{ to: 'iec' }) or { '' } == '2.0M'
	assert numfmt('200000.5', mut app, Options{ to: 'iec-i' }) or { '' } == '196Ki'
	assert numfmt('2000000.6', mut app, Options{ to: 'iec-i' }) or { '' } == '2.0Mi'
	assert numfmt('2000000.6', mut app, Options{ to: 'none' }) or { '' } == '2000001'
}
