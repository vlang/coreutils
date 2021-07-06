import os
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

fn output_of(arg string) string {
	if product := strconv.parse_uint(arg, 10, 64) {
		factors := prime_factors(product)
		return '$product: ${factors.map(it.str()).join(' ')}'
	} else {
		return 'factor: ‘$arg’ is not a valid positive integer'
	}
}

const (
	usage = 'Usage: factor [NUMBER]...
  or:  factor OPTION
Print the prime factors of each specified integer NUMBER.  If none
are specified on the command line, read them from standard input.

      --help     display this help and exit
      --version  output version information and exit'
	version = 'factor (V coreutils 0.0.1)'
)

fn main() {
	match os.args.len {
		1 {
			for {
				println(output_of(os.input('')))
			}
		}
		else {
			for arg in os.args[1..] {
				match arg {
					'--help' {
						println(usage)
						exit(0)
					}
					'--version' {
						println(version)
						exit(0)
					}
					else {
						println(output_of(arg))
					}
				}
			}
		}
	}
}
