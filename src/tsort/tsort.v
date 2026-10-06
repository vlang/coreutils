import os
import common

const app_name = 'tsort'

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Topological sort of a partial ordering.')
	fp.allow_unknown_args()
	fp.finalize()!

	mut files := fp.remaining_parameters()
	if files.len == 0 {
		files = ['-']
	}
	mut failed := false
	for file in files {
		if !tsort_file(file) {
			failed = true
		}
	}
	if failed {
		exit(1)
	}
}

fn tsort_file(file string) bool {
	source := if file == '-' { '-' } else { file }
	data := if file == '-' {
		mut out := []u8{}
		mut buf := []u8{len: 64 * 1024}
		mut f := os.stdin()
		for {
			n := f.read(mut buf) or { break }
			if n == 0 {
				break
			}
			out << buf[..n]
		}
		out
	} else {
		if !os.exists(file) {
			eprintln('${app_name}: ${file}: No such file or directory')
			return false
		}
		os.read_bytes(file) or {
			eprintln('${app_name}: ${file}: ${err.msg()}')
			return false
		}
	}
	return tsort(data, source)
}

fn tsort(data []u8, source string) bool {
	// Parse the pairs. Each line holds two tokens; a line with an odd number is
	// an error, and blank lines are skipped.
	mut edges := [][2]string{}
	{
	}
	mut order := []string{}
	mut seen := map[string]bool{}
	for line in data.bytestr().split('\n') {
		tokens := line.split(' ')
		mut words := []string{}
		for t in tokens {
			if t != '' {
				words << t
			}
		}
		if words.len == 0 {
			continue
		}
		if words.len % 2 != 0 {
			eprintln('${app_name}: ${source}: input contains an odd number of tokens')
			return false
		}
		for i := 0; i < words.len; i += 2 {
			u := words[i]
			v := words[i + 1]
			edges << [u, v]!
			for node in [u, v] {
				if !seen[node] {
					seen[node] = true
					order << node
				}
			}
		}
	}
	// Kahn's algorithm: start with the nodes nothing points at, then work through
	// the edges. The order nodes are first seen is the order they are considered in.
	mut indeg := map[string]int{}
	mut adj := map[string][]string{}
	for node in order {
		indeg[node] = 0
		adj[node] = []string{}
	}
	for e in edges {
		// A self loop is not a cycle: GNU prints the node once and exits 0, so the
		// edge is dropped rather than counted.
		if e[0] == e[1] {
			continue
		}
		adj[e[0]] << e[1]
		indeg[e[1]]++
	}
	mut queue := []string{}
	for node in order {
		if indeg[node] == 0 {
			queue << node
		}
	}
	mut out := []string{}
	// Taken from the front rather than the back, so the order matches GNU: a stack
	// would reverse the independent chains relative to the order they were read in.
	mut qi := 0
	for qi < queue.len {
		node := queue[qi]
		qi++
		out << node
		for next in adj[node] {
			indeg[next]--
			if indeg[next] == 0 {
				queue << next
			}
		}
	}
	// Whatever is left is in a loop. GNU still prints those nodes and reports the
	// loop on standard error, so the nodes go out first and the exit code is what
	// says the input was not a DAG.
	has_loop := out.len < order.len
	if has_loop {
		for node in order {
			if !out.contains(node) {
				out << node
			}
		}
		eprintln('${app_name}: ${source}: input contains a loop:')
	}
	for node in out {
		println(node)
	}
	return !has_loop
}
