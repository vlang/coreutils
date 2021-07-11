import os
import common
import strconv

fn prime_factors(product u64) []u64 {
	mut factors := []u64{}
	mut number := product

	for factor := u64(2); factor <= number; factor += 2 {
		if number % factor == 0 {
			factors << factor
			number /= factor
			factor = 0
		} else if factor * factor > number {
			factors << number
			break
		} else if factor * factor == number {
			factors << factor
			factors << factor
			break
		}
		if factor == 2 {
			factor = 1
		}
	}

	return factors
}

fn output_of(arg string) ?string {
	if product := strconv.parse_uint(arg, 10, 64) {
		factors := prime_factors(product)
		if factors.len > 0 {
			return '$product: ${factors.map(it.str()).join(' ')}'
		} else {
			return '$product:'
		}
	}
	return error('factor: ‘$arg’ is not a valid positive integer')
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('factor')
	fp.usage_example('[NUMBER]...')
	fp.usage_example('OPTION')
	fp.description('Print the prime factors of each specified integer NUMBER.')
	fp.description('If none are specified on the command line, read them from standard input.')
	args := fp.remaining_parameters()
	mut errors := 0
	if args.len == 0 {
		for {
			println(output_of(os.input_opt('') or { common.exit_on_errors(errors) }) or {
				errors++
				eprintln(err.msg)
				continue
			})
		}
	} else {
		for arg in args {
			println(output_of(arg) or {
				errors++
				eprintln(err.msg)
				continue
			})
		}
	}
	common.exit_on_errors(errors)
}
