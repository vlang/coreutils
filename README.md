# coreutils in V

This repository contains programs equivalent to GNU
[coreutils](https://www.gnu.org/software/coreutils/), written in the
[V language](https://vlang.io).

## Goal

Complete set of coreutils, written as closely as possible to the POSIX spec,
with as many GNU extensions as feasible.

We are looking for solid, working implementations of the commands, not 100%
1-to-1 parity, especially not quirks and unintended side-effects.

The reference implementation is GNU coreutils 8.32.

## Layout

Each command has it's own separate subdirectory under `src`, in case the
implementor wishes to create multiple `.v` files to implement a command, or add
a README.md specifically for that command.

## Developing

Please use the `common` module for command line/help handling. This will make
the command input/output consistent across the tools.

## Building

Running `make` or `v run build.vsh` will build all the programs in `bin/`.

Note: support for access to user account info (via utmp) is limited to POSIX-like platforms.
And, so, for Windows, utilities requiring utmp support (uptime, users, who, whoami) are currently
skipped during the default build process.

## Contributing

Contributions are welcome!

Please only contribute versions of the original utilities written in V.
Contributions written in other languages will likely be rejected.

When your contribution is finalized, don't forget to update the completed
count below and mark it as done in this README.md. Thanks!

**NOTE: When testing on Windows**, comparison tests are currently run against
[uutils/coreutils](https://github.com/uutils/coreutils), a Rust re-implementation of
GNU coreutils. They are not 100% compatiable. If you encounter different behaviors,
compare against the true GNU coreutils version on the Linux-based tests first.

## Completed (74/109) - 68% done!

|  Done   | Cmd       | Descripton                                       | Windows | 
| :-----: | --------- | ------------------------------------------------ | ------- |
| &check; | **[**     | Alternate form of `test`                         | &check; |
| &check; | arch      | Print machine hardware name                      |         |
| &check; | b2sum     | Print or check BLAKE2 digests                    | &check; |
| &check; | base32    | Transform data into printable data               | &check; |
| &check; | base64    | Transform data into printable data               | &check; |
| &check; | basename  | Strip directory and suffix from a file name      | &check; |
| &check; | basenc    | Transform data into printable data               | &check; |
| &check; | cat       | Concatenate and write files                      | &check; |
|         | chcon     | Change SELinux context of file                   | &check; |
|         | chgrp     | Change group ownership                           |         |
|         | chmod     | Change access permissions                        |         |
|         | chown     | Change file owner and group                      |         |
|         | chroot    | Run a command with a different root directory    |         |
| &check; | cksum     | Print CRC checksum and byte counts               | &check; |
|         | comm      | Compare two sorted files line by line            | &check; |
|         | coreutils | Multi-call program                               | &check; |
| &check; | cp        | Copy files and directories                       | &check; |
|         | csplit    | Split a file into context-determined pieces      | &check; |
| &check; | cut       | Print selected parts of lines                    | &check; |
|         | date      | Print or set system date and time                | &check; |
|         | dd        | Convert and copy a file                          | &check; |
|         | df        | Report file system disk space usage              |         |
|         | dir       | Briefly list directory contents                  |         |
|         | dircolors | Color setup for ls                               | &check; |
| &check; | dirname   | Strip last file name component                   | &check; |
|         | du        | Estimate file space usage                        | &check; |
| &check; | echo      | Print a line of text                             | &check; |
| &check; | env       | Run a command in a modified environment          | &check; |
| &check; | expand    | Convert tabs to spaces                           | &check; |
| &check; | expr      | Evaluate expressions                             | &check; |
| &check; | factor    | Print prime factors                              | &check; |
| &check; | false     | Do nothing, unsuccessfully                       | &check; |
| &check; | fmt       | Reformat paragraph text                          | &check; |
| &check; | fold      | Wrap input lines to fit in specified width       | &check; |
| &check; | groups    | Print group names a user is in                   |         |
| &check; | head      | Output the first part of files                   | &check; |
| &check; | hostid    | Print numeric host identifier                    |         |
| &check; | hostname  | Print or set system name                         |         |
| &check; | id        | Print user identity                              |         |
|         | install   | Copy files and set attributes                    |         |
|         | join      | Join lines on a common field                     | &check; |
|         | kill      | Send a signal to processes                       | &check; |
| &check; | link      | Make a hard link via the link syscall            | &check; |
| &check; | ln        | Make links between files                         | &check; |
| &check; | logname   | Print current login name                         | &check; |
| &check; | ls        | List directory contents                          |         |
| &check; | md5sum    | Print or check MD5 digests                       | &check; |
| &check; | mkdir     | Make directories                                 | &check; |
| &check; | mkfifo    | Make FIFOs (named pipes)                         | &check; |
|         | mknod     | Make block or character special files            | &check; |
| &check; | mktemp    | Create temporary file or directory               | &check; |
| &check; | mv        | Move (rename) files                              | &check; |
|         | nice      | Run a command with modified niceness             |         |
| &check; | nl        | Number lines and write files                     | &check; |
| &check; | nohup     | Run a command immune to hangups                  | &check; |
| &check; | nproc     | Print the number of available processors         | &check; |
| &check; | numfmt    | Reformat numbers                                 | &check; |
|         | od        | Write files in octal or other formats            | &check; |
| &check; | paste     | Merge lines of files                             | &check; |
|         | pathchk   | Check file name validity and portability         | &check; |
|         | pinky     | Lightweight finger                               |         |
|         | pr        | Paginate or columnate files for printing         | &check; |
| &check; | printenv  | Print all or some environment variables          | &check; |
| &check; | printf    | Format and print data                            | &check; |
|         | ptx       | Produce permuted indexes                         | &check; |
| &check; | pwd       | Print working directory                          | &check; |
| &check; | readlink  | Print value of a symlink or canonical file name  | &check; |
|         | realpath  | Print the resolved file name                     | &check; |
| &check; | rm        | Remove files or directories                      | &check; |
| &check; | rmdir     | Remove empty directories                         | &check; |
|         | runcon    | Run a command in specified SELinux context       | &check; |
| &check; | seq       | Print numeric sequences                          | &check; |
| &check; | sha1sum   | Print or check SHA-1 digests                     | &check; |
| &check; | sha224sum | Print or check SHA-2 224 bit digests             | &check; |
| &check; | sha256sum | Print or check SHA-2 256 bit digests             | &check; |
| &check; | sha384sum | Print or check SHA-2 384 bit digests             | &check; |
| &check; | sha512sum | Print or check SHA-2 512 bit digests             | &check; |
| &check; | shred     | Remove files more securely                       | &check; |
| &check; | shuf      | Shuffling text                                   | &check; |
| &check; | sleep     | Delay for a specified time                       | &check; |
| &check; | sort      | Sort text files                                  | &check; |
|         | split     | Split a file into pieces                         | &check; |
| &check; | stat      | Report file or file system status                |         |
|         | stdbuf    | Run a command with modified I/O stream buffering |         |
|         | stty      | Print or change terminal characteristics         |         |
| &check; | sum       | Print checksum and block counts                  | &check; |
| &check; | sync      | Synchronize cached writes to persistent storage  | &check; |
| &check; | tac       | Concatenate and write files in reverse           | &check; |
| &check; | tail      | Output the last part of files                    | &check; |
|         | tee       | Redirect output to multiple files or processes   | &check; |
| &check; | test      | Check file types and compare values              | &check; |
|         | timeout   | Run a command with a time limit                  |         |
| &check; | touch     | Change file timestamps                           | &check; |
|         | tr        | Translate, squeeze, and/or delete characters     | &check; |
| &check; | true      | Do nothing, successfully                         | &check; |
| &check; | truncate  | Shrink or extend the size of a file              | &check; |
|         | tsort     | Topological sort                                 | &check; |
| &check; | tty       | Print file name of terminal on standard input    |         |
| &check; | uname     | Print system information                         | &check; |
| &check; | unexpand  | Convert spaces to tabs                           | &check; |
| &check; | uniq      | Uniquify files                                   | &check; |
| &check; | unlink    | Remove files via the unlink syscall              | &check; |
| &check; | uptime    | Print system uptime and load                     |         |
| &check; | users     | Print login names of users currently logged in   |         |
|         | vdir      | Verbosely list directory contents                |         |
| &check; | wc        | Print newline, word, and byte counts             | &check; |
|         | who       | Print who is currently logged in                 |         |
| &check; | whoami    | Print effective user ID                          | &check; |
| &check; | yes       | Print a string until interrupted                 | &check; |

Windows &check; if the utility exists in the [Windows version of GNU coreutils](https://github.com/mingw-io/coreutils).
