module main

import arch
import hostid
import logname
import pwd
import os
import true as true_tool
import tty
import yes
import whoami

// multicall is the busybox-style binary: one executable that contains several
// tools and dispatches to the one named on the command line.
//
// A converted tool is a V module exposing `pub fn run(args []string) int`, and
// both this binary and the standalone binary built for the same tool go through
// that same function. So the two build styles cannot drift apart, which is the
// usual failure of a multicall: the single binary quietly implements something
// the per-tool binaries do not, because they are two copies of the code.
//
// Dispatch is by argv[0] first, so a symlink or hardlink named after the tool
// works with no sub-command, exactly as busybox does. A tool name given as the
// first argument also works, which is how this repo's earlier `coreutils`
// dispatcher was invoked.
//
// The exclusion list is short, and it is a property of the name rather than of the
// tool, so it is worth stating once rather than discovering per tool. Only three
// tools are excluded, verified by trying each import rather than by guessing:
//
//   true, false - V keywords. module false does not parse, and a module name
//                  has to match its directory, so no alias can reach it.
//   sync         - vlib ships a top-level sync module for Mutex, RwMutex and
//                  WaitGroup, and import sync resolves to that. An alias does
//                  not redirect it either: import sync as probe_sync compiles
//                  with no more than an unused-import warning, which is how this
//                  was confirmed rather than inferred.
//
// alse is absent on purpose: V rejects module false because false is a
// keyword, and a module name has to match its directory, so the tool cannot be
// imported here without renaming its directory. The standalone bin/false binary// is unaffected and stays on disk.
//
// Tools not converted to a module are likewise absent rather than broken.
const tools = {
	'arch':    arch.run
	'hostid':  hostid.run
	'logname': logname.run
	'pwd':     pwd.run
	'true':    true_tool.run
	'tty':     tty.run
	'whoami':  whoami.run
	'yes':     yes.run
}

fn main() {
	args := os.args
	// argv[0] is the path this binary was invoked as; its last component is
	// the name to dispatch on when the binary is linked or symlinked per tool.
	invoked := os.base(os.executable())

	mut name := ''
	mut rest := []string{}
	if invoked in tools {
		name = invoked
		rest = args[1..]
	} else if args.len > 1 && args[1] in tools {
		name = args[1]
		rest = args[2..]
	}

	run := tools[name] or {
		if name == '' {
			eprintln('${invoked}: no tool given, and ${invoked} is not itself a tool')
		} else {
			eprintln('${invoked}: unknown tool ${name}')
		}
		eprintln('available: ' + sorted_names())
		exit(1)
	}
	exit(run(prepend(argv0(args[0]), rest)))
}

// The tool's own argument parsing expects argv[0] to be the first element,
// because common.flag_parser treats it as the program name. Rebuild that shape
// so the flag parser sees what it would see when run as its own binary.
fn prepend(argv0 string, rest []string) []string {
	mut a := [argv0]
	a << rest
	return a
}

fn sorted_names() string {
	mut names := []string{}
	for k, _ in tools {
		names << k
	}
	names.sort()
	return names.join(', ')
}

// argv0 is the first argument the tool was invoked with, so its help text names
// itself rather than this binary.
fn argv0(raw string) string {
	return raw
}
