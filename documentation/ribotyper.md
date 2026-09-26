# <a name="top"></a> `ribotyper` example usage, command-line options and unexpected feature information

* [`ribotyper` example usage](#exampleusage)
* [Unexpected features and reasons for a sequence to _FAIL_](#unexpectedfeatures)
* [The `ribotyper` default model library](#library)
* [`ribotyper`'s two round search strategy](#strategy)
* [Defining acceptable/questionable models](#acceptable)
* [List of all command-line options](#options)

---

`ribotyper` is a tool for classifying and validating SSU and/or LSU
rRNA sequences in an input. A central assumption of the script is that
 each input sequence is a SSU or LSU rRNA sequence (either full length
or partial). Therefore, it is not well suited for identifying rRNAs in
genome sequences or metagenomic datasets.

`ribotyper` compares each sequence to a library of profile HMMs built
from representative alignments of SSU and LSU rRNA sequences.  Each
profile HMM is a statistical model of the family it models
(e.g. bacterial SSU rRNA) built from a multiple alignment of 50-100
representative sequences from the family. The source of several of the
alignments, including the bacterial SSU model, is the [Rfam](rfam.xfam.org) database.
For more information on the models see [this page](#models.md).
Each profile HMM has position specific scores at
each position of the model, which means that positions of the family
that are highly conserved have a higher impact on the final score than
do positions that are not as well conserved (unlike BLAST for which
each position is treated identically). Each sequence is aligned to
each profile and a score is computed based on how well the sequence
matches the profile. Each sequence is classified by the model that
gave it the highest score.

Each sequence is determined to either *pass* or *fail* the program
based on if any of a set of *unexpected features* are detected for
it. Sequences with zero fatal *unexpected features* *pass* and all
others *fail*. The set of possible unexpected features is described
more [below](#unexpectedfeatures) and includes matching best to an
unexpected model (UnacceptableModel) and having a low score
(LowScore). Information about defining the set of acceptable models
can also be found [below](#acceptable). 

## <a name="exampleusage"></a>`ribotyper` example usage

This example runs the script `ribotyper` on a sample file of 16
sequences.

Move into a directory in which you have write permission and execute the following command:

```
> ribotyper $RIBOSCRIPTSDIR/testfiles/example-16.fa test
```

Like other Ribovore scripts, `ribotyper` takes two required command
line arguments. Optional arguments are explained [below](#options).

The first required argument is the sequence file you want to annotate.
The $RIBOSCRIPTSDIR environment variable should be defined in your
`.bashrc` or `.cshrc` as explained in the [installation
documentation](install.md#environment).

The second required argument is the name of the output subdirectory
that you would like `ribotyper` to create. Output files will be placed
in this output directory. If this directory already exists, the
program will exit with an error message indicating that you need to
either (a) remove the directory before rerunning, or (b) use the -f
option, in which case the directory will be
overwritten.  The command adding `-f` is:

```
> ribotyper -f $RIBOSCRIPTSDIR/testfiles/example-16.fa test
```

You should see something like the following output:
```
# ribotyper :: detect and classify ribosomal RNA sequences
# Ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:              Tue Dec 22 16:04:25 2020
# $RIBOEASELDIR:     /usr/local/src/ribovore-install/infernal/binaries
# $RIBOINFERNALDIR:  /usr/local/src/ribovore-install/infernal/binaries
# $RIBOSCRIPTSDIR:   /usr/local/src/ribovore-install/ribovore
#
# target sequence input file:   /usr/local/src/ribovore-install/ribovore/testfiles/example-16.fa
# output directory name:        test
# forcing directory overwrite:  yes [-f]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Validating input files                                                           ... done. [    0.6 seconds]
# Determining target sequence lengths                                              ... done. [    0.1 seconds]
# Classifying sequences                                                            ... done. [    2.2 seconds]
# Sorting classification results                                                   ... done. [    0.0 seconds]
# Processing classification results                                                ... done. [    0.0 seconds]
# Fetching per-model sequence sets                                                 ... done. [    0.0 seconds]
# Searching sequences against best-matching models                                 ... done. [    1.0 seconds]
# Concatenating tabular round 2 search results                                     ... done. [    0.0 seconds]
# Sorting search results                                                           ... done. [    0.0 seconds]
# Processing tabular round 2 search results                                        ... done. [    0.0 seconds]
# Creating final output files                                                      ... done. [    0.0 seconds]
#
# Summary statistics:
#
#                number  fraction  average   average   fraction     number
# class         of seqs  of total   length  coverage  that PASS  that FAIL
# ------------  -------  --------  -------  --------  ---------  ---------
  *input*            16    1.0000  1328.69    1.0000          -          -
#
  SSU.Archaea         5    0.3125  1303.60    0.9662     1.0000          0
  SSU.Bacteria        5    0.3125  1295.40    0.9798     1.0000          0
  SSU.Eukarya         5    0.3125  1452.80    0.9590     1.0000          0
#
  *all*              16    1.0000  1328.69    0.9078     0.9375          1
  *none*              1    0.0625  1000.00    0.0000     0.0000          1
#
# Unexpected feature statistics:
#
#                     causes     number  fraction
# unexpected feature  failure?  of seqs   of seqs
# ------------------  --------  -------  --------
  CLEAN               no             11   0.68750
  *NoHits             yes             1   0.06250
  MinusStrand         no              3   0.18750
  LowCoverage         no              1   0.06250
#
#
# Timing statistics:
#
# stage           num seqs  seq/sec      nt/sec  nt/sec/cpu  total time             
# --------------  --------  -------  ----------  ----------  -----------------------
  classification        16      7.2      9550.9      9550.9              00:00:02.23
  search                15     14.7     19828.3     19828.3              00:00:01.02
  total                 16      3.9      5219.0      5219.0              00:00:04.07
#
#
# List and description of all output files saved in:   test.ribotyper.list
# Output printed to screen saved in:                   test.ribotyper.log
# List of executed commands saved in:                  test.ribotyper.cmd
# Short (6 column) output saved in:                    test.ribotyper.short.out
# Long (25 column) output saved in:                    test.ribotyper.long.out
#
# All output files created in directory ./test/
#
# Elapsed time:  00:00:04.07
#                hh:mm:ss
# 
[ok]
```

`ribotyper` outputs information on each step and how long it takes,
followed by `Summary statistics` that show how many sequences were
classified to each class (e.g. `SSU.Archaea`). After this comes the
`Unexpected feature statistics`, which are explained more below, and
`Timing statistics`, and a list of important output files.  In the
output of the program PASS/FAIL and CLEAN are in all caps only for
emphasis.

The two output files that end in `.out` include per-sequence tabular
data, with one line per sequence with fields separated by whitespace
(spaces, not tabs). These two files, along with all output files, will
both be in the new directory `test` that was created by the example
run above.

The two file types are a 'short' file of 6 columns, and a 'long' file
with 20 columns with more information. Each file includes a
description of the columns at the end of the file.

Unless `--nodupfilter` is used, the output directory also includes a
tab-delimited `.dupfilter.tsv` file with one line per pair of
overlapping hits checked by the [DuplicateRegion filter](#dupfilter)
(hit and extract coordinates, extract lengths and AT fraction, `blastn`
bit score, threshold, call, and whether the sequence's alert was
`removed` or kept as `FATAL`). If the filter was not applied, its first
line gives the reason.

With `--keep`, the round 2 search output (including alignments) is
saved in one file per model, `.r2.<model>.cmsearch.out` (with
`--nodupfilter`, all models share one `.r2.cmsearch.out` file, so only
the last model's output is kept).

<a name="short"></a> The short file is included below. Note that the meaning of the columns are briefly explained
in comment lines (prefixed with `#`) after the tabular output, along with explanations of
possible values in the `unexpected_features` column. These are explained more [below](#unexpectedfeatures).
```
> cat test/test.ribotyper.short.out
#idx  target                                         classification         strnd   p/f  unexpected_features
#---  ---------------------------------------------  ---------------------  -----  ----  -------------------
1     00052::Halobacterium_sp.::AE005128             SSU.Archaea            plus   PASS  -
2     00013::Methanobacterium_formicicum::M36508     SSU.Archaea            plus   PASS  -
3     00004::Nanoarchaeum_equitans::AJ318041         SSU.Archaea            plus   PASS  -
4     00121::Thermococcus_celer::M21529              SSU.Archaea            plus   PASS  LowCoverage:(0.835<0.860);
5     random                                         -                      -      FAIL  *NoHits;
6     00115::Pyrococcus_furiosus::U20163|g643670     SSU.Archaea            minus  PASS  MinusStrand;
7     00035::Bacteroides_fragilis::M61006|g143965    SSU.Bacteria           plus   PASS  -
8     01106::Bacillus_subtilis::K00637               SSU.Bacteria           plus   PASS  -
9     00072::Chlamydia_trachomatis.::AE001345        SSU.Bacteria           plus   PASS  -
10    01351::Mycoplasma_gallisepticum::M22441        SSU.Bacteria           minus  PASS  MinusStrand;
11    00224::Rickettsia_prowazekii.::AJ235272        SSU.Bacteria           plus   PASS  -
12    01223::Audouinella_hermannii.::AF026040        SSU.Eukarya            plus   PASS  -
13    01240::Batrachospermum_gelatinosum.::AF026045  SSU.Eukarya            plus   PASS  -
14    00220::Euplotes_aediculatus.::M14590           SSU.Eukarya            plus   PASS  -
15    00229::Oxytricha_granulifera.::AF164122        SSU.Eukarya            minus  PASS  MinusStrand;
16    01710::Oryza_sativa.::X00755                   SSU.Eukarya            plus   PASS  -
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Explanation of columns:
#
# Column 1 [idx]:                 index of sequence in input sequence file
# Column 2 [target]:              name of target sequence
# Column 3 [classification]:      classification of sequence
# Column 4 [strnd]:               strand ('plus' or 'minus') of best-scoring hit
# Column 5 [p/f]:                 PASS or FAIL (reasons for failure begin with '*' in rightmost column)
# Column 6 [unexpected_features]: unexpected/unusual features of sequence (see below)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
#
# Explanation of possible values in unexpected_features column:
#
# This column will include a '-' if none of the features listed below are detected.
# Or it will contain one or more of the following types of messages. There are no
# whitespaces in this field, to make parsing easier.
#
# Values that begin with "*" automatically cause a sequence to FAIL.
# Values that do not begin with "*" do not cause a sequence to FAIL.
#
#  1.  *NoHits                 No primary hits to any models above the minimum primary score
#                              threshold of 20 bits (--minpsc) were found.
#  2.  *MultipleFamilies       One or more primary hits to two or more "families" (e.g. SSU
#                              or LSU) exists for the same sequence.
#  3.  *BothStrands            One or more primary hits above the minimum primary score threshold
#                              of 20 bits (--minpsc) were found on each strand.
#  4.  *DuplicateRegion        At least two hits (primary or secondary) on the same strand overlap
#                              in model coordinates by 20 (--maxoverlap) positions or more
#  5.  *InconsistentHits       Not all hits (primary or secondary) are in the same order in the
#                              sequence and in the model.
#  6.  MinusStrand             Best hit is on the minus strand.
#  7.  LowScore                The bits per nucleotide (total bit score divided by total length
#                              of sequence) is below threshold of 0.5 (--lowppossc).
#  8.  LowCoverage             The total coverage of all hits (primary and secondary) to the best
#                              model (summed length of all hits divided by total length of sequence)
#                              is below threshold of 0.86 (--tcov).
#  9.  LowScoreDifference      The difference between the top two domains is below the 'low'
#                              threshold of 0.10 (--lowpdiff) bits per position (total bit score
#                              divided by summed length of all hits).
# 10.  VeryLowScoreDifference  The difference between the top two domains is below the 'very low'
#                              threshold of 0.04 (--vlowpdiff) bits per position (total bit score
#                              divided by summed length of all hits).
# 11.  MultipleHits            There is more than one hit to the best scoring model on the same strand.
#

```
The `test/test.ribotyper.long.out` file is not shown because its lines are so wide, but it
also includes brief descriptions of each column. An example is in `testfiles/test.ribotyper.long.out`

## <a name="unexpectedfeatures"></a> Unexpected features and reasons for a sequence to _FAIL_

There are several *unexpected features* of sequences that are detected
and reported in the rightmost column of both the short and long output
files. These unexpected features can cause a sequence to FAIL, as
explained below.  

There are 15 possible unexpected features that get reported, some of
which are related to each other. Eleven of the 15 can arise when
`ribotyper` is used with default arguments, and therefore appear in
the example above; the other four can arise only when specific
additional non-default arguments are used, as explained
below. Therefore, the list of 15 features below, with long
descriptions, subsumes the list of 11 features given above with
shorter descriptions.  Eight of the unexpected features will always
cause a sequence to fail. The other seven unexpected features *can*
cause a sequence to fail, but only if specific command line options
are used.

You can tell which unexpected features cause sequences to FAIL for a
particular `ribotyper` run by looking at the unexpected feature column (final
column) of the short or long output files: those that cause failures
will begin with the '*' character (e.g. `*NoHits`) and those that do
not cause failures will not begin with a "*". You can control which
unexpected features cause failures using command line options as
explained below in the descriptions of each unexpected feature.

List of unexpected features:

1. ***NoHits***: No hits to any models above the minimum primary score
threshold were found. The minimum primary score threshold is 20 bits,
which should find all legitimate SSU/LSU sequences, but this minimum
primary score threshold is changeable to `<x>` with the `--minpsc
<x>`. ***Always causes failure***.

    Example message in `.out` output files:

    `NoHits`; indicating no hits were found

2. ***UnacceptableModel***: Best hit is to a model that is
'unacceptable'. By default, all models are acceptable, but the user
can specify only certain top-scoring models are 'acceptable' using the
`--inaccept <s>` option. If `--inaccept` is not used, this unexpected
feature will never be reported. An example of using `--inaccept` is
given [below](#acceptable). ***Always causes failure***.

    Example message in `.out` output files:

    `UnacceptableModel:(SSU_rRNA_eukarya)`; indicating top hit is to the `SSU_rRNA_eukarya` model which was not listed as `acceptable` or `questionable` in file `<f>` from command-line option `--inaccept <f>` (see example [below](#acceptable))


3. ***MultipleFamilies***: hit to two or more 'families' (e.g. SSU or LSU)
exists for the same sequence. This would happen, for example, if a
single sequence had a fragment of an SSU sequence and a fragment of an
LSU sequence on it. Only hits with scores at or above primary bit
score threshold of 20 bits (changeable to `<x>` with `--minpsc <x>`)
are considered. ***Always causes failure***.

    Example message in `.out` output files:

    `MultipleFamilies:(SSU+LSU,LSU:LSU_rRNA_eukarya:55.7/1443-2303:+)`; indicating that hits to models in families `SSU` and `LSU` (see `family` column in `modelinfo` [file](#library) exist for this sequence and *lower-scoring* hit is to family `LSU` with model `LSU_rRNA_eukarya` with a score of `55.7` bits from positions `1443-2303` on the `+` strand

4. ***BothStrands***: At least 1 hit above minimum primary bit score
threshold of 20 bits to the best model exists on both strands. ***Always
causes failure***.

    Example messages in `.out` output files:

    `BothStrands:(+:1_hit(s)[3359_nt],-:1_hit(s)[33_nt])`; indicating that `1` hit exists on the `+` strand with total length of `3359` nucleotides and `1` hit exists on the `-` strand with total length of `33` nucleotides

    `BothStrands:(+:3_hit(s),-:2_hit(s))`; indicating that `3` hits exists on the `+` strand of indeterminate length and `2` hits exists on the `-` strand of indeterminate length

5. ***DuplicateRegion***: At least two hits overlap in model coordinates
by `P` positions or more. The threshold `P` is 10 by default but can be
changed to `<n>` with the `--maxoverlap <n>` option. ***Always causes 
failure***, but by default the alert is first checked by the
[DuplicateRegion filter](#dupfilter) and removed if the overlapping
hits are no more similar to each other than chance.

    Example message in `.out` output files:

    `DuplicateRegion:(220-253)_hits_2_and_3(M:220.909,11.253,S:259.970,3.207)`; indicating that hits `2` and `3` to the best model overlap in model coordinates `220` to `253` and that model coordinates of hit `2` are `220` to `909`, and model coordinates of hit `3` are `11` to `253` and that sequence coordinates of hit `2` are `259` to `970`, and sequence coordinates of hit `3` are `3` to `207`

6. ***InconsistentHits***: The hits to the best model are
inconsistent in that they are not in the same order in the sequence
and the model, possibly indicating a misassembly. ***Always causes
failure***.

    Example message in `.out` output files:

    `InconsistentHits:seq_order(1,2[56.1322,1385.1407]),mdl_order(2,1[103.1356,7.29])`; indicating that hit `1` comes before hit `2` in the sequence (hit `1` sequence positions are `56` to `1322` and hit `2` sequence positinos are `1385` to `1407`) but hit `1` comes after hit `2` in the model (hit `1` model positions are `103` to `1356` and hit `2` model positions are `7` to `29`)

    <a name="dupfilter"></a>**The DuplicateRegion filter (on by default; turn it off with `--nodupfilter`).**
    Two hits can overlap in model coordinates without the sequence
    containing a duplication, for example when a divergent or AT-rich
    region matches the same part of the model twice by chance. So, by
    default, each pair of overlapping hits behind a DuplicateRegion alert
    is checked: the residues of each hit that align to the overlapping
    model positions are extracted and compared to each other with one
    `blastn` call, and the maximum bit score is compared with a threshold
    for extracts of those lengths and base composition, precomputed from
    random sequence pairs (`models/ribo.dupfilter.null.tsv` in
    `$RIBOSCRIPTSDIR`). If **no** pair scores above its threshold (that
    is, no pair is more similar than chance, p >= 0.05), the alert is
    removed: it is not reported and does not cause failure. Otherwise the
    alert is reported exactly as it would be without the filter. So every
    DuplicateRegion alert that `ribotyper` reports causes failure. Each
    adjudicated pair, including every removed alert, is listed in the
    `.dupfilter.tsv` output file.

    Limits of the filter:
    * It answers the question "are the two regions more similar than
      chance?", not "is this alert a problem?". An exact tandem repeat is
      always significant, so its alert is always kept.
    * DuplicateRegion itself rarely fires on duplications shorter than
      about 100-200 nucleotides, so the filter mostly sees long ones.
    * On simulated true duplications of 100 nucleotides or more, about
      0.5% of the duplications that a Smith-Waterman alignment plus
      shuffle test calls significant are called not significant by the
      filter (so their alerts would be removed), mostly AT-rich or
      divergent ones with short extracts.
    * Removing an alert changes `ribotyper`'s PASS/FAIL for that
      sequence. It can also change `ribosensor`'s output. A sequence
      with a DuplicateRegion alert always also has a MultipleHits
      unexpected feature, but `ribosensor` ignores MultipleHits for a
      sequence that `rRNA_sensor` passes, so such a sequence can go
      from FAIL to PASS in `ribosensor`. In every case the GenBank
      error `SEQ_HOM_MisAsDupRegion` is no longer reported for a
      removed alert, which can also change whether a failing sequence
      fails to the submitter or to the indexer.
    * The filter is not applied, and every alert is kept, with `--1slow`,
      `--1hmm`, `--1blast`, `--2slow`, `--noali` or `--skipsearch` (the
      reason is recorded in the `.log` and `.dupfilter.tsv` files).

    **Installation requirements of the filter.** The same version of
    `ribotyper` run with the same options must give the same results on
    every installation, so if the filter is on and cannot run exactly as
    released, `ribotyper` stops with an error rather than silently
    skipping it. The error message says what is wrong and how to fix it.
    `ribotyper` exits with an error, **before any search starts**, if:
    * `blastn` in `$RIBOBLASTDIR` does not exist or is not executable;
    * `blastn -version` reports a version the filter has not been tested
      with (tested: 2.11.0+ and 2.14.1+; `install.sh` installs 2.14.1+);
    * the threshold table `models/ribo.dupfilter.null.tsv` in
      `$RIBOSCRIPTSDIR` is missing, unreadable, or not the exact file
      released with this version of Ribovore (its md5 checksum is
      checked). To fix this, re-run the Ribovore installation, or restore
      the file from the Ribovore release matching your version at
      [https://github.com/NLM-DIR/ribovore](https://github.com/NLM-DIR/ribovore).

    It also stops with an error during the run if a `blastn` comparison
    fails or its output cannot be read, a temporary file cannot be
    written, or the round 2 search output cannot be read or does not
    contain the alignments of the hits behind an alert.

    The only way to run without the filter is the `--nodupfilter` option
    (results will then differ from a default run). `riboaligner` and
    `ribodbmaker` can pass it to `ribotyper` in the file given with
    their `--riboopts` (`riboaligner`) or `--riboopts1` and `--riboopts2`
    (`ribodbmaker`) options. `ribosensor` has no way to pass it, so
    for `ribosensor` the installation problem must be fixed.

7. ***QuestionableModel***: Best hit is to a model that is
'questionable'. By default, no models are questionable, but the user
can specify certain top-scoring models are 'questionable' using the
`--inaccept <s>` option. If `--inaccept` is not used, this unexpected
feature will never be reported. An example of using `--inaccept` is
given [below](#acceptable). ***Only causes failure if the `--questfail`
options is enabled***.

    Example message in `.out` output files:

    `QuestionableModel:(SSU_rRNA_chloroplast)`; indicating top hit is to the `SSU_rRNA_chloroplast` model which was listed as `questionable` in file `<f>` from command-line option `--inaccept <f>` (see example [below](#acceptable))

8. ***MinusStrand***: The best hit is on the minus strand. ***Only causes
failure if the `--minusfail` option is enabled***.

    Example message in `.out` output files:

    `MinusStrand`; indicating top hit is on minus strand

9. ***LowScore***: the bits per nucleotide statistic (total bit score
divided by length of total sequence (not just length of hit)) is below
threshold. By default the threshold is 0.5 bits per position, but this
can be changed to `<x>` with the `--lowppossc <x>` option. The total
bit score is calculated as the sum of all hits with scores at or above
the secondary bit score threshold, which is 10 bits by default but
changeable to `<x>` with the `--minssc <x>` option. ***Only causes
failure if the `--scfail` option is enabled***.

    Example message in `.out` output files:

    `LowScore:(0.43<0.50)`; indicating bits per nucleotide is 0.43, below threshold of 0.50

10. ***LowCoverage***: the total coverage of all hits to the best model
(summed length of all hits divided by total sequence length) is below
threshold. By default the threshold is 0.86, but it can be changed to
`<x>` with the `--tcov <x>` option; `<x>` should be between 0 and 1.
Additionally, one can set a different coverage threshold for 'short'
sequences using the `--tshortcov <x1>` option, which must be used in
combination with the `--tshortlen <n>` option which specifies that
sequences less than or equal to `<n>` nucleotides in length will be
subject to the coverage threshold `<x1>` from `--tshortcov <x1>`.  The
total length of all hits calculated as the sum of the length of all
hits with scores at or above the secondary bit score threshold, which
is 10 bits by default but changeable to `<x>` with the `--minssc <x>`
option.  ***Only causes failure if the `--covfail` option is enabled***.

    Example message in `.out` output files:

    `LowCoverage(0.835<0.860)`; indicating total coverage is 0.835, below threshold of 0.86

11. ***LowScoreDifference***: the score
difference between the top two domains is below the 'low'
threshold. By default this is the score per position difference, and
the 'low' threshold is 0.10 bits per position, but this is changeable
to <x> bits per position with the `--lowpdiff` option. The difference
can be changed from bits per position to total bits with the `--absdiff`
option. If `--absdiff` is used, the threshold is 100 bits, but
changeable to <x> with the `--lowadiff` <x> option. ***Only causes failure
if the `--difffail` option is enabled***.

    Example message in `.out` output files:

    `LowScoreDifference:(0.052<0.10_bits_per_posn)`; indicating that the score per position difference between the top two models is `0.052`, below the threshold of `0.10`.

12. ***VeryLowScoreDifference***: the score
difference between the top two domains is below the 'very low'
threshold. By default this is the score per position difference, and
the 'very low' threshold is 0.04 bits per position, but this is
changeable to `<x>` bits per position with the `--vlowpdiff` option. The
difference can be changed from bits per position to total bits with
the `--absdiff` option. If `--absdiff` is used, the threshold is 40 bits,
but changeable to <x> with the `--vlowadiff <x>` option. ***Only causes
failure if the `--difffail` option is enabled***.

    Example message in `.out` output files:

    `VeryLowScoreDifference:(0.009<0.040_bits_per_posn)`; indicating that the score per position difference between the top two models is `0.009`, below the threshold of `0.040`.

13. ***MultipleHits***: there are more than one hits with scores above the
secondary bit score threshold of 10 bits (changeable to `<x>` bits
with `--minssc <x>`) to the best matching model. ***Only causes failure if the 
`--multfail` option is enabled***.

    For the MultipleHits unexpected feature, the output includes information on the gap between every pair of adjacent hits including a classification of each gap into one of three classes based on the size of the gap in both model coordinates and sequence coordinates as described below. These classifications depend on two thresholds: the maximum size of a *small* gap in model coordinates (referred to below as *small model gap*), set as `10` by default, but settable to `<n>` with the `--mgap <n>` option, and the maximum size of a *small* gap in sequence coordinates (referred to below as *small sequence gap*), set as `10` by default, but settable to `<n>` with the `--sgap <n>` option.

    Three classes of gaps in MultipleHits output strings:
    - *sequence insertion*: the model gap length is less than or equal to the maximum size of a small model gap, regardless of size of gap in sequence coordinates; abbreviated as `SI` in the output, see below for an example
    - *model deletion*:     the model gap length is more than the maximum size of a small model gap and the sequence gap length is less than or equal to the maximum size of a small sequence gap; abbreviated as `MD` in the output, see below for an example
    - *nonhomologous region*: if the model gap length is more than the maximum size of a small model gap and the sequence gap length is more than the maximum size of a small sequence gap; abbreviated as `NH` in the output, see below for an example

    Example messages in `.out` output files:

    `MultipleHits:(2:SI[M:10(1161..1170),S:10(1121..1130)])`; indicating that there are `2` hits and the gap between hits `1` and `2` has been classified as a *sequence insertion* (`SI`); the gap between hit 1 and 2 is `10` positions in the model (`M`) from model positions `1161` to `1170`, and `10` positions in the sequence (`S`) from sequence positions `1121` to `1130`. 

    `MultipleHits:(2:MD[M:33(1133..1165),S:0(1061..1062)])`; indicating that there are `2` hits and the gap between hits `1` and `2` has been classified as a *model deletion* (`MD`); the gap between hit 1 and 2 is `33` positions in the model (`M`) from model positions `1133` to `1165`, and `0` positions in the sequence (`S`) and occurs between sequence positions `1061` and `1062`. 

    `MultipleHits:(2:NH[M:24(1152..1175),S:24(1112..1135)])`; indicating that there are `2` hits and the gap between hits `1` and `2` has been classified as a *nonhomologous region* (`NH`); the gap between hit 1 and 2 is `24` positions in the model (`M`) from model positions `1152` to `1175`, and `24` positions in the sequence (`S`) from sequence positions `1112` and `1135`. 

14. ***EvalueScoreDiscrepancy***: hits were sorted by E-value due to the `--evalues`
option and the second best hit had higher bit score than the best hit and the bit
score difference between those two hits exceeded threshold. By default, that threshold
is 0.001 bits but this is changeable to <x> bits with the `--esdmaxsc <x>` option.
***Only reported if the `--evalues` option is enabled. Only causes failure if the 
`--esdfail` option is enabled***.

    Example message in `.out` output files:           

    `EvalueScoreDiscrepancy:(second_hit_by_evalue_bit_score_exceeds_top_hit_by_evalue_bit_score_by_4.457>0.001_bits`; indicating that the second best hit by E-value has a higher bit score (`4.457` bits higher) than the best hit by E-value
    
15. ***TooShort***: the sequence is too short, less than `<n1>`
nucleotides in length, where `<n1>` is defined with the `--shortfail
<n1>` option. ***Always causes failure when reported but only reported if the 
`--shortfail <n1>` option is enabled***.

    Example message in `.out` output files:           

    `TooShort:(127<200)`; indicating sequence length is `127` which is less than the minimum length of `200` nt set by the `--shortfail 200` option
    
16. ***TooLong***: the sequence is too long, more than `<n2>` nucleotides in
length, where `<n2>` is defined with the `longfail <n2>` option. ***Always
causes failure when reported but only reported if the `--longfail <n2>`
option is enabled***. 

    Example message in `.out` output files:           

    `TooLong:(4217>3000)`; indicating sequence length is `4217` which is greater than the maximum length of `3000` nt set by the `--longfail 3000` option

## <a name="library"></a> The `ribotyper` default model library

By default, `ribotyper` will use its default model library (installed in
`$RIBOSCRIPTSDIR/models/ribotyper.cm`) which includes 15 SSU rRNA
profiles and 3 LSU rRNA profiles. More information on the model library
can be found [here](models.md#library).

`ribotyper` requires a `modelinfo` file that includes information on the
model library it uses. The `modelinfo` file that goes along with the
default model library is `$RIBOSCRIPTSDIR/models/ribotyper.modelinfo`.

That file is included below:
```
> cat $RIBOSCRIPTSDIR/models/ribotyper.modelinfo
# Each non-# prefixed line should have 4 white-space delimited tokens:
#<modelname> <family> <domain> <CM-file-with-only-this-model>
# The first line is special, it indicates the name of the master CM file
# with all the models in it
#model                         family domain             cmfile
*all*                             -   -                  ribotyper.cm
SSU_rRNA_archaea                  SSU Archaea            rt.SSU_rRNA_archaea.enone.cm
SSU_rRNA_bacteria                 SSU Bacteria           rt.SSU_rRNA_bacteria.enone.cm
SSU_rRNA_eukarya                  SSU Eukarya            rt.SSU_rRNA_eukarya.enone.cm
SSU_rRNA_microsporidia            SSU Euk-Microsporidia  rt.SSU_rRNA_microsporidia.enone.cm
SSU_rRNA_chloroplast              SSU Plast-Chloroplast  rt.SSU_rRNA_chloroplast.enone.cm
SSU_rRNA_mito_metazoa             SSU Mito-Metazoa       rt.SSU_rRNA_mito_metazoa.enone.cm
SSU_rRNA_cyanobacteria            SSU Bacteria           rt.SSU_rRNA_cyanobacteria.enone.cm
LSU_rRNA_archaea                  LSU Archaea            rt.LSU_rRNA_archaea.enone.cm
LSU_rRNA_bacteria                 LSU Bacteria           rt.LSU_rRNA_bacteria.enone.cm
LSU_rRNA_eukarya                  LSU Eukarya            rt.LSU_rRNA_eukarya.enone.cm
LSU_rRNA_microsporidia            LSU Euk-Microsporidia  rt.LSU_rRNA_microsporidia.cm
SSU_rRNA_apicoplast               SSU Plast-Apicoplast   rt.SSU_rRNA_apicoplast.enone.cm
SSU_rRNA_chloroplast_pilostyles   SSU Plast-Chloroplast-Pilostyles rt.SSU_rRNA_chloroplast_pilostyles.enone.cm
SSU_rRNA_mito_amoebozoa           SSU Mito-Amoebozoa     rt.SSU_rRNA_mito_amoebozoa.enone.cm
SSU_rRNA_mito_chlorophyta         SSU Mito-Chlorophyta   rt.SSU_rRNA_mito_chlorophyta.enone.cm
SSU_rRNA_mito_fungi               SSU Mito-Fungi         rt.SSU_rRNA_mito_fungi.enone.cm
SSU_rRNA_mito_kinetoplastea       SSU Mito-Kinetoplastea rt.SSU_rRNA_mito_kinetoplastea.enone.cm
SSU_rRNA_mito_embryophyta         SSU Mito-Embryophyta   rt.SSU_rRNA_mito_embryophyta.enone.cm
SSU_rRNA_mito_ciliophora          SSU Mito-Ciliophora    rt.SSU_rRNA_mito_ciliophora.enone.cm
SSU_rRNA_mito_bigyra              SSU Mito-Bigyra        rt.SSU_rRNA_mito_bigyra.enone.cm
SSU_rRNA_mito_oomycota            SSU Mito-Oomycota      rt.SSU_rRNA_mito_oomycota.enone.cm
SSU_rRNA_mito_cryptophyceae       SSU Mito-Cryptophyceae rt.SSU_rRNA_mito_cryptophyceae.enone.cm
SSU_rRNA_mito_choanoflagellata    SSU Mito-Choanoflagellata rt.SSU_rRNA_mito_choanoflagellata.enone.cm
SSU_rRNA_mito_protist_other       SSU Mito-Protist-Other rt.SSU_rRNA_mito_protist_other.enone.cm
SSU_rRNA_mito_protostomia         SSU Mito-Protostomia   rt.SSU_rRNA_mito_protostomia.enone.cm
LSU_rRNA_mito_vertebrata                 LSU Mito-Vertebrata           rt.LSU_rRNA_mito_vertebrata.cm
LSU_rRNA_mito_bilateria                  LSU Mito-Bilateria            rt.LSU_rRNA_mito_bilateria.cm
LSU_rRNA_mito_arthropoda                 LSU Mito-Arthropoda           rt.LSU_rRNA_mito_arthropoda.cm
LSU_rRNA_mito_eukaryote                  LSU Mito-Eukaryote            rt.LSU_rRNA_mito_eukaryote.cm
LSU_rRNA_mito_embryophyta                LSU Mito-Embryophyta          rt.LSU_rRNA_mito_embryophyta.cm
LSU_rRNA_mito_nematoda                   LSU Mito-Nematoda             rt.LSU_rRNA_mito_nematoda.cm
LSU_rRNA_mito_kinetoplastea               LSU Mito-Kinetoplastea       rt.LSU_rRNA_mito_kinetoplastea.cm
LSU_rRNA_chloroplast                     LSU Plast-Chloroplast         rt.LSU_rRNA_chloroplast.cm
LSU_rRNA_apicoplast                      LSU Plast-Apicoplast          rt.LSU_rRNA_apicoplast.cm
```

Using this file will classify sequences SSU and LSU sequences from any
of the listed domains. 

You can create your own `modelinfo` and CM files and use them with `ribotyper`, with the `-i` option.

## <a name="strategy"></a>`ribotyper`'s two round search strategy

`ribotyper` proceeds in two rounds. The first round is called the
*classification* stage. In this round, all models are compared against
all sequences using a fast profile HMM algorithm that does not do a
good job at defining boundaries of SSU/LSU sequences, but is good at
determining if a sequence is a SSU/LSU sequence or not. For each
comparison, a bit score is reported. For each sequence, the model that
gives that sequence the highest bit score is defined as the
'best-matching' model for that sequence.
 
In the second round, each model is used to search again against the set of
sequences for which it is the best-matching model. This time, a slower but
more powerful profile HMM algorithm is used that is better at defining
sequence boundaries. This round takes about as much time as the first
round even though the algorithm is slower because at most one model is
compared against each sequence. 

## <a name="acceptable"></a> Defining acceptable/questionable models

The user can provide an additional input file that specifies which
models are 'acceptable' or 'questionable'. For GenBank, this usage can
be relevant when the submitter has made claims about which types of
SSU or LSU sequences are being submitted. In that situation, the
models consistent with the submitter's claims should be acceptable and
all other models should be questionable. All sequences for which the
highest ranked (by bit score unless the option `--evalues` is used)
hit is _not_ one of the acceptable or questionable models, will FAIL for
Reason 6 above. All sequences for which the top hit is one of the
questionable models will be reported with 'questionable_model' in
their `unexpected_feature` string (and will FAIL if the `--questfail` option
is enabled) (Reason 7 above).

*If the `--inaccept` option is not used, then _all_ models listed in the
`.modelinfo` file will be considered acceptable and none will be
considered questionable.*

An example input file that specifies that only the SSU_rRNA_bacteria
and SSU_rRNA_cyanobacteria as 'acceptable' from model file 1 is:
`$RIBOSCRIPTSDIR/models/ribosensor.ssu-arc-bac.accept`:

```
> cat $RIBOSCRIPTSDIR/models/ribosensor.ssu-arc-bac.accept
# A list of 'acceptable' and 'questionable' models.
# Each non-# prefixed line has 2 tokens, separated by a space.
# First token is the name of a model. 
# Second token is either 'acceptable' or 'questionable'.
#
# 'acceptable' means that this model is allowed and no 'unusual
# features' will be reported for sequences for which this model is the
# best-scoring model
#
# 'questionable' means that this model will have the
# 'questionable_model' unusual feature reported for it.
#
# Any model not listed here will have the 'unacceptable_model'
# unusual feature reported for it.
SSU_rRNA_archaea acceptable
SSU_rRNA_bacteria acceptable
SSU_rRNA_cyanobacteria acceptable
SSU_rRNA_chloroplast questionable
```

To use this on the example run from above, use the `--inaccept`
option:

```
> ribotyper -f --inaccept $RIBOSCRIPTSDIR/models/ribosensor.ssu-arc-bac.accept $RIBOSCRIPTSDIR/testfiles/example-16.fa test2
```

Now, the short output file will set any family that was classified as
a model other than SSU_rRNA_archaea, SSU_rRNA_bacteria,
SSU_rRNA_cyanobacteria, or SSU_rRNA_chloroplast as FAILs, and the
string `*UnacceptableModel` will be present in the
`unexpected_features` column.

```
> cat test2/test2.ribotyper.short.out 
#idx  target                                         classification         strnd   p/f  unexpected_features
#---  ---------------------------------------------  ---------------------  -----  ----  -------------------
1     00052::Halobacterium_sp.::AE005128             SSU.Archaea            plus   PASS  -
2     00013::Methanobacterium_formicicum::M36508     SSU.Archaea            plus   PASS  -
3     00004::Nanoarchaeum_equitans::AJ318041         SSU.Archaea            plus   PASS  -
4     00121::Thermococcus_celer::M21529              SSU.Archaea            plus   PASS  LowCoverage:(0.835<0.860);
5     random                                         -                      -      FAIL  *NoHits;
6     00115::Pyrococcus_furiosus::U20163|g643670     SSU.Archaea            minus  PASS  MinusStrand;
7     00035::Bacteroides_fragilis::M61006|g143965    SSU.Bacteria           plus   PASS  -
8     01106::Bacillus_subtilis::K00637               SSU.Bacteria           plus   PASS  -
9     00072::Chlamydia_trachomatis.::AE001345        SSU.Bacteria           plus   PASS  -
10    01351::Mycoplasma_gallisepticum::M22441        SSU.Bacteria           minus  PASS  MinusStrand;
11    00224::Rickettsia_prowazekii.::AJ235272        SSU.Bacteria           plus   PASS  -
12    01223::Audouinella_hermannii.::AF026040        SSU.Eukarya            plus   FAIL  *UnacceptableModel:(SSU_rRNA_eukarya);
13    01240::Batrachospermum_gelatinosum.::AF026045  SSU.Eukarya            plus   FAIL  *UnacceptableModel:(SSU_rRNA_eukarya);
14    00220::Euplotes_aediculatus.::M14590           SSU.Eukarya            plus   FAIL  *UnacceptableModel:(SSU_rRNA_eukarya);
15    00229::Oxytricha_granulifera.::AF164122        SSU.Eukarya            minus  FAIL  *UnacceptableModel:(SSU_rRNA_eukarya);MinusStrand;
16    01710::Oryza_sativa.::X00755                   SSU.Eukarya            plus   FAIL  *UnacceptableModel:(SSU_rRNA_eukarya);
#
```

## <a name="options"></a>List of all command-line options

You can see all the available command line options to `ribotyper` by
calling it at the command line with the -h option:

```
> ribotyper -h
# ribotyper :: detect and classify ribosomal RNA sequences
# Ribovore 1.0 (Feb 2021)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:    Tue Dec 22 16:56:29 2020
#
Usage: ribotyper [-options] <fasta file to annotate> <output directory>

basic options:
  -f     : force; if <output directory> exists, overwrite it
  -v     : be verbose; output commands to stdout as they're run
  -n <n> : use <n> CPUs [0]
  -i <s> : use model info file <s> instead of default

options for controlling the first round search algorithm:
  --1hmm  : run first round in slower HMM mode
  --1slow : run first round in slow CM mode that scores structure+sequence

options for controlling the second round search algorithm:
  --2slow : run second round in slow CM mode that scores structure+sequence

options related to bit score REPORTING thresholds:
  --minpsc <x> : set minimum bit score cutoff for primary hits to include to <x> bits [20.]
  --minssc <x> : set minimum bit score cutoff for secondary hits to include to <x> bits [10.]

options for controlling which sequences PASS/FAIL (turning on optional failure criteria):
  --minusfail     : hits on negative (minus) strand defined as FAILures
  --scfail        : seqs that fall below low score threshold FAIL
  --difffail      : seqs that fall below low score difference threshold FAIL
  --covfail       : seqs that fall below low coverage threshold FAIL
  --multfail      : seqs that have more than one hit to best model FAIL
  --questfail     : seqs that score best to questionable models FAIL
  --shortfail <n> : seqs that are shorter than <n> nucleotides FAIL [0]
  --longfail <n>  : seqs that are longer than <n> nucleotides FAIL [0]
  --esdfail       : seqs in which second best hit by E-value has better bit score above threshold FAIL

options for controlling thresholds for failure/warning criteria:
  --lowppossc <x>  : set minimum bit per position threshold for reporting suspiciously low scores to <x> bits [0.5]
  --tcov <x>       : set low total coverage threshold to <x> fraction of target sequence [0.86]
  --tshortcov <x>  : set low total coverage threshold for short seqs to <x> fraction of target sequence
  --tshortlen <n>  : set maximum length for short seq coverage threshold to <n> nucleotides
  --lowpdiff <x>   : set 'low'      per-posn score difference threshold to <x> bits [0.10]
  --vlowpdiff <x>  : set 'very low' per-posn score difference threshold to <x> bits [0.04]
  --absdiff        : use total score difference thresholds instead of per-posn
  --lowadiff <x>   : set 'low'      total score difference threshold to <x> bits [100.]
  --vlowadiff <x>  : set 'very low' total score difference threshold to <x> bits [40.]
  --maxoverlap <n> : set maximum allowed number of model positions to overlap b/t 2 hits before failure to <n> [20]
  --esdmaxsc <x>   : set maximum allowed bit score difference for E-value/score discrepancies to <x> [0.001]

optional input files:
  --inaccept <s> : read acceptable/questionable domains/models from file <s>

options that modify the behavior of --1slow or --2slow:
  --mid         : with --1slow/--2slow use cmsearch --mid option instead of --rfam
  --max         : with --1slow/--2slow use cmsearch --max option instead of --rfam
  --smxsize <x> : with --max also use cmsearch --smxsize <x>

options for parallelizing cmsearch on a compute farm:
  -p         : parallelize cmsearch on a compute farm
  -q <s>     : use qsub info file <s> instead of default
  -s <n>     : seed for random number generator is <n> [181]
  --nkb <n>  : number of KB of sequence for each cmsearch farm job is <n> [100]
  --wait <n> : allow <n> wall-clock minutes for cmsearch jobs on farm to finish, including queueing time [500]
  --errcheck : consider any farm stderr output as indicating a job failure

options for controlling gap type definitions:
  --mgap <n> : maximum size of a 'small' gap in model coordinates is <n> [10]
  --sgap <n> : maximum size of a 'small' gap in sequence coordinates is <n> [10]

options for creating additional output files:
  --outseqs      : save per-model pass/fail sequences to files
  --outhits      : save per-model pass/fail sequences to files
  --outgaps      : save gap sequences between hits to a file
  --outxgaps <n> : save gap sequence file with <n> added nts [20]
  --keep         : keep all intermediate files that are removed by default

advanced options:
  --evalues    : rank hits by E-values, not bit scores
  --skipsearch : skip search stage, use results from earlier run
  --noali      : no alignments in output, requires --keep
  --samedomain : top two hits can be to models in the same domain
  --skipval    : skip validation of CM and model info files
  --onlyval    : validate CM and model info files and exit

option for the *DuplicateRegion filter (on by default)
  [see the DuplicateRegion filter section above for what the filter does, its limits and its installation requirements]
  --nodupfilter : do not filter *DuplicateRegion alerts with blastn: report every one, FATAL
```

---

#### Questions, comments or feature requests? Send a mail to eric.nawrocki@nih.gov.
