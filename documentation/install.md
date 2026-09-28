#  <a name="top"></a> Ribovore installation instructions

* [Installation using `install.sh`](#install.sh)
* [Setting environment variables](#environment)
* [Verifying successful installation](#tests)

---
## Ribovore installation using the `install.sh` script <a name="install"></a>

The file `install.sh` is an executable file for installing Ribovore
and its dependencies. That file is located online at github.
To install the latest version of Ribovore download this file:

https://raw.githubusercontent.com/NLM-DIR/ribovore/master/install.sh

To download any specific release/version, for example version 1.0 download
the corresponding `install.sh` file for that release/version.

https://raw.githubusercontent.com/NLM-DIR/ribovore/ribovore-1.0/install.sh

Copy the `install.sh` file into the directory in which you want
to install Ribovore. A good name for that directory is
`ribovore-install`. Then move into that directory and run the install
script. There are six possible ways to run `install.sh` and its usage can be
viewed by executing the script without any arguments:

```
>sh ./install.sh
Usage:   ./install.sh <os>
 or 
Usage:   ./install.sh <os> keep

valid options for <os> are:
  "linux":             full install for linux
  "macosx-intel":      full install for macosx-intel
  "macosx-silicon":    full install for macosx-silicon
  "rt-linux":          ribotyper only for linux
  "rt-macosx-intel":   ribotyper only for macosx-intel
  "rt-macosx-silicon": ribotyper only for macosx-silicon

use "keep" as 2nd argument to keep nonessential files
which are normally removed
```

The command you should use for installation depends on your
operating system and whether or not you want to install the full
Ribovore package or just want to use the `ribotyper` script.

For example, to install on a linux machine, execute:

```
sh ./install.sh linux
```

The `linux`, `macosx-intel`, or `macosx-silicon` argument controls the
type of infernal and blast executable files that will be installed and
also dictates whether the `vecscreen_plus_taxonomy` package will be
installed. `vecscreen_plus_taxonomy` will be installed only for
`linux` installations and consequently only `linux` installations will
be able to use all features of `ribodbmaker`. Mac/OSX installations
will be able to run `ribodbmaker` but only with specific flags that
cause steps that require executable programs that get installed with
`vecscreen_plus_taxonomy` to be skipped, as explained more [here.](ribodbmaker.md#macosx)

The `install.sh` command will create several directories in the
current directory.  It will download and install Ribovore and the
required module libraries
[sequip](https://github.com/nawrockie/sequip), as well as the binary
executables of [Infernal](http://eddylab.org/infernal/), the NCBI
BLAST package (for either Linux or Mac/OSX), and (if Linux) the
[vecscreen_plus_taxonomy](https://github.com/aaschaffer/vecscreen_plus_taxonomy)
package.

The installation procedure will remove some unnecessary files from the
dependencies it installs (infernal and blast) by default, but these
files can be kept if you additionally add `keep` as an additional
argument, for example:

```
sh ./install.sh linux keep
```

When `install.sh` is finished running it will print important
instructions to the screen that explain how to modify your environment
variables so that you can run the Ribovore scripts, as discussed next.

---

## Setting Ribovore environment variables <a name="environment"></a>

As mentioned above, when you run `install.sh`, instructions will be
output about how to change your environment variables so that you can
run the Ribovore scripts. Those instructions are also included below for
reference, but without the actual path to where you ran `install.sh`
(below it is replaced with `<full path to directory in which you ran
install.sh>`)

---

### <a name="environment"></a> Instructions for setting environment variables output by `install.sh`


```
The final step is to update your environment variables.
(See ribovore/README.txt for more information.)

If you are using the bash or zsh shell add the following lines to
the end of your '.bashrc' or '.zshrc' file in your home directory:

export RIBOINSTALLDIR="<full path to directory in which you ran install.sh>"
export RIBOSCRIPTSDIR="$RIBOINSTALLDIR/ribovore"
export RIBOINFERNALDIR="$RIBOINSTALLDIR/infernal/binaries"
export RIBOEASELDIR="$RIBOINSTALLDIR/infernal/binaries"
export RIBOSEQUIPDIR="$RIBOINSTALLDIR/sequip"
export RIBOTIMEDIR="/usr/bin"
export RIBOBLASTDIR="$RIBOINSTALLDIR/ncbi-blast/bin"
export RRNASENSORDIR="$RIBOINSTALLDIR/rRNA_sensor"
export VECPLUSDIR="$RIBOINSTALLDIR/vecscreen_plus_taxonomy"
export VECSCREENDIR="$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts"
export SRCCHKDIR="$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts"
export BLASTDB="$VECPLUSDIR/univec-files":"$RRNASENSORDIR":"$BLASTDB"
export PERL5LIB="$RIBOSCRIPTSDIR":"$RIBOSEQUIPDIR":"$VECPLUSDIR":"$PERL5LIB"
export PATH="$RIBOSCRIPTSDIR":"$RIBOBLASTDIR":"$RRNASENSORDIR":"$PATH"

After adding the export lines to your .bashrc or .zshrc file, source that file
to update your current environment with the command:

source ~/.bashrc

OR

source ~/.zshrc

---
If you are using the C shell, add the following
lines to the end of your '.cshrc' file in your home
directory:

setenv RIBOINSTALLDIR "<full path to directory in which you ran install.sh>"
setenv RIBOSCRIPTSDIR "$RIBOINSTALLDIR/ribovore"
setenv RIBOINFERNALDIR "$RIBOINSTALLDIR/infernal/binaries"
setenv RIBOEASELDIR "$RIBOINSTALLDIR/infernal/binaries"
setenv RIBOSEQUIPDIR "$RIBOINSTALLDIR/sequip"
setenv RIBOTIMEDIR "/usr/bin"
setenv RIBOBLASTDIR "$RIBOINSTALLDIR/ncbi-blast/bin"
setenv RRNASENSORDIR "$RIBOINSTALLDIR/rRNA_sensor"
setenv VECPLUSDIR "$RIBOINSTALLDIR/vecscreen_plus_taxonomy"
setenv VECSCREENDIR "$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts"
setenv SRCCHKDIR "$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts"
setenv BLASTDB "$VECPLUSDIR/univec-files":"$RRNASENSORDIR":"$BLASTDB"
setenv PERL5LIB "$RIBOSCRIPTSDIR":"$RIBOSEQUIPDIR":"$VECPLUSDIR":"$PERL5LIB"
setenv PATH "$RIBOSCRIPTSDIR":"$RIBOBLASTDIR":"$RRNASENSORDIR":"$PATH"

After adding the setenv lines to your .cshrc file, source that file
to update your current environment with the command:

source ~/.cshrc

(To determine which shell you use, type: 'echo $SHELL')
```

For Mac/OSX installations, the `VECPLUSDIR`, `VECSCREENDIR` and
`SRCCHKDIR` lines will be omitted, the `BLASTDB` lines will not
include `$VECPLUSDIR/univec-files`, and the `PERL5LIB` line will not
include `$VECPLUSDIR`.

---

### If you get an error about `PERL5LIB` and/or `BLASTDB` being undefined...

If you use bash or zsh, change the PERL5LIB and/or `BLASTDB` line in your `~/.bashrc` or
`~/.zshrc` file to:

```
export PERL5LIB="$RIBOSCRIPTSDIR":"$RIBOSEQUIPDIR":"$VECPLUSDIR"
export BLASTDB="$VECPLUSDIR/univec-files":"$RRNASENSORDIR"
````


or if you use C shell, change the PERL5LIB line in your `~/.cshrc`
file to:

```
setenv PERL5LIB "$RIBOSCRIPTSDIR":"$RIBOSEQUIPDIR":"$VECPLUSDIR"
setenv BLASTDB "$VECPLUSDIR/univec-files":"$RRNASENSORDIR"
```

And then execute `source ~/.bashrc`, `source ~/.zshrc`, or `source ~/.cshrc` again.

---
## <a name="tests"></a> Verifying successful installation with test runs

Ribovore includes some tests you can run after setting your
environment variables as explained above to make sure that your
installation was successful and that your environment variables are
set correctly.

These are several shell scripts for running tests; with respect to the
installation directory they are in the directory `ribovore/testfiles/` and
start with `do-` and end with `.sh`.

You should run the `$RIBOSCRIPTSDIR/testfiles/do-all-tests.sh` script
to make sure Ribovore installed correctly. They should pass, as shown
below.

There is also a special test script `do-parallel-tests.sh` that you
should run if you want to test if you can use the `-p` option with
`ribotyper`, `ribosensor`, `riboaligner` or `ribodbmaker` for
parallelization on a cluster.  But this test will likely only work
internally at NCBI. See this [example](ribotyper.md#exampleparallel)
for more information.  `do-parallel-tests.sh` is **not** run as part
of `do-all-tests.sh`.

To run all tests, execute:

```
$RIBOSCRIPTSDIR/testfiles/do-all-tests.sh
```

This script can take up to several minutes to run. 
If something goes wrong, the script will likely exit quickly.

Below is an example of the expected output for
`do-all-tests.sh` for a linux installation:

```
# ribotest :: test ribovore scripts [TEST SCRIPT]
# ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:             Wed Feb  3 18:02:23 2021
# $RIBOSCRIPTSDIR:  /usr/local/src/ribovore-install/ribovore
#
# test file:                                                         /usr/local/src/ribovore-install/ribovore/testfiles/ribotyper.testin
# output directory name:                                             rt-test
# forcing directory overwrite:                                       yes [-f]
# if output files listed in testin file already exist, remove them:  yes [--rmout]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Running command  1 [      ribotyper-1-16]          ... done. [    8.2 seconds]
#	checking test-16/test-16.ribotyper.short.out                 ... pass
#	checking test-16/test-16.ribotyper.long.out                  ... pass
#	removing directory test-16                                   ... done
# Running command  2 [     ribotyper-2-100]          ... done. [   22.6 seconds]
#	checking r100/r100.ribotyper.short.out                       ... pass
#	checking r100/r100.ribotyper.long.out                        ... pass
#	removing directory r100                                      ... done
#
#
# PASS: all 4 files were created correctly.
#
#
# List and description of all output files saved in:   rt-test.ribotest.list
# Output printed to screen saved in:                   rt-test.ribotest.log
# List of executed commands saved in:                  rt-test.ribotest.cmd
#
# All output files created in directory ./rt-test/
#
# Elapsed time:  00:00:30.99
#                hh:mm:ss
# 
[ok]
Success: all tests passed [do-ribotyper-tests.sh]
# ribotest :: test ribovore scripts [TEST SCRIPT]
# ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:             Wed Feb  3 18:02:54 2021
# $RIBOSCRIPTSDIR:  /usr/local/src/ribovore-install/ribovore
#
# test file:                                                         /usr/local/src/ribovore-install/ribovore/testfiles/riboaligner.testin
# output directory name:                                             ra-test
# forcing directory overwrite:                                       yes [-f]
# if output files listed in testin file already exist, remove them:  yes [--rmout]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Running command  1 [    riboaligner-1-16]          ... done. [   13.9 seconds]
#	checking test-16-2/test-16-2.riboaligner.tbl                 ... pass
#	checking test-16-2/test-16-2.riboaligner.SSU.Bacteria.partial.stk ... pass
#	checking test-16-2/test-16-2.riboaligner.SSU.Bacteria.partial.list ... pass
#	checking test-16-2/test-16-2.riboaligner.SSU.Bacteria.partial.ifile ... pass
#	checking test-16-2/test-16-2.riboaligner.SSU.Bacteria.partial.elfile ... pass
#	removing directory test-16-2                                 ... done
# Running command  2 [   riboaligner-2-100]          ... done. [   85.7 seconds]
#	checking r100-2/r100-2.riboaligner.tbl                       ... pass
#	checking r100-2/r100-2.riboaligner.SSU.Eukarya.partial.list  ... pass
#	checking r100-2/r100-2.riboaligner.SSU.Eukarya.partial.ifile ... pass
#	checking r100-2/r100-2.riboaligner.SSU.Eukarya.partial.elfile ... pass
#	checking r100-2/r100-2.riboaligner.SSU.Eukarya.partial.stk   ... pass
#	removing directory r100-2                                    ... done
#
#
# PASS: all 10 files were created correctly.
#
#
# List and description of all output files saved in:   ra-test.ribotest.list
# Output printed to screen saved in:                   ra-test.ribotest.log
# List of executed commands saved in:                  ra-test.ribotest.cmd
#
# All output files created in directory ./ra-test/
#
# Elapsed time:  00:01:40.43
#                hh:mm:ss
# 
[ok]
Success: all tests passed [do-riboaligner-tests.sh]
# ribotest :: test ribovore scripts [TEST SCRIPT]
# ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:             Wed Feb  3 18:04:36 2021
# $RIBOSCRIPTSDIR:  /usr/local/src/ribovore-install/ribovore
#
# test file:                                                         /usr/local/src/ribovore-install/ribovore/testfiles/ribosensor.testin
# output directory name:                                             rs-test
# forcing directory overwrite:                                       yes [-f]
# if output files listed in testin file already exist, remove them:  yes [--rmout]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Running command  1 [     ribosensor-1-16]          ... done. [   14.5 seconds]
#	checking test-rs-16/test-rs-16.ribosensor.out                ... pass
#	checking test-rs-16/test-rs-16.ribosensor.gbank              ... pass
#	removing directory test-rs-16                                ... done
# Running command  2 [    ribosensor-2-100]          ... done. [   42.5 seconds]
#	checking rs-r100/rs-r100.ribosensor.out                      ... pass
#	checking rs-r100/rs-r100.ribosensor.gbank                    ... pass
#	removing directory rs-r100                                   ... done
#
#
# PASS: all 4 files were created correctly.
#
#
# List and description of all output files saved in:   rs-test.ribotest.list
# Output printed to screen saved in:                   rs-test.ribotest.log
# List of executed commands saved in:                  rs-test.ribotest.cmd
#
# All output files created in directory ./rs-test/
#
# Elapsed time:  00:00:57.31
#                hh:mm:ss
# 
[ok]
Success: all tests passed [do-ribosensor-tests.sh]
# ribotest :: test ribovore scripts [TEST SCRIPT]
# ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:             Wed Feb  3 18:05:34 2021
# $RIBOSCRIPTSDIR:  /usr/local/src/ribovore-install/ribovore
#
# test file:                                                         /usr/local/src/ribovore-install/ribovore/testfiles/ribodbmaker-vec.testin
# output directory name:                                             rdb-test
# forcing directory overwrite:                                       yes [-f]
# if output files listed in testin file already exist, remove them:  yes [--rmout]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Running command  1 [ribodbmaker-vec-1-100]         ... done. [  145.4 seconds]
#	checking db100vec/db100vec.ribodbmaker.rdb.tbl               ... pass
#	removing directory db100vec                                  ... done
#
#
# PASS: all 1 files were created correctly.
#
#
# List and description of all output files saved in:   rdb-test.ribotest.list
# Output printed to screen saved in:                   rdb-test.ribotest.log
# List of executed commands saved in:                  rdb-test.ribotest.cmd
#
# All output files created in directory ./rdb-test/
#
# Elapsed time:  00:02:25.70
#                hh:mm:ss
# 
[ok]
Success: all tests passed [do-ribodbmaker-tests.sh]
# ribotest :: test ribovore scripts [TEST SCRIPT]
# ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:             Wed Feb  3 18:08:00 2021
# $RIBOSCRIPTSDIR:  /usr/local/src/ribovore-install/ribovore
#
# test file:                                                         /usr/local/src/ribovore-install/ribovore/testfiles/github-issues/iss1/iss1.testin
# output directory name:                                             iss1-out
# forcing directory overwrite:                                       yes [-f]
# if output files listed in testin file already exist, remove them:  yes [--rmout]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Running command  1 [         iss1-ribodb]          ... done. [   11.9 seconds]
#	checking db1/db1.ribodbmaker.rdb.tbl                         ... pass
#	removing directory db1                                       ... done
#
#
# PASS: all 1 files were created correctly.
#
#
# List and description of all output files saved in:   iss1-out.ribotest.list
# Output printed to screen saved in:                   iss1-out.ribotest.log
# List of executed commands saved in:                  iss1-out.ribotest.cmd
#
# All output files created in directory ./iss1-out/
#
# Elapsed time:  00:00:12.03
#                hh:mm:ss
# 
[ok]
Success: all tests passed [do-iss1-tests.sh]
Success: all tests passed [do-all-issue-tests.sh]
Success: all tests passed [do-all-tests.sh]
```
The most important line is the final line:

```
Success: all tests passed
```

This means that the test has passed. You should see similar 
lines if you run the other tests. If you do not and need help
figuring out why, email me at eric.nawrocki@nih.gov.

---
#### Questions, comments or feature requests? Send a mail to eric.nawrocki@nih.gov.


