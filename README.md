# Ribovore <a name="top"></a>
#### Version 1.0.5; September 2023
#### https://github.com/NLM-DIR/ribovore.git

Ribovore is a suite of tools for detecting, classifying and analyzing
small subunit ribosomal RNA (SSU rRNA) and large subunit (LSU) rRNA
sequences. It is used by GenBank to validate incoming 16S SSU rRNA
sequences and to generate high quality datasets of SSU and LSU rRNA
sequences for RefSeq and for use as blastn databases. Ribovore is
written in Perl.

The [`ribotyper`](documentation/ribotyper.md#top) program is used to
quickly validate and classify rRNA sequences using profile models of
SSU and LSU rRNA genes from different taxonomic groups.

The [`ribosensor`](documentation/ribosensor.md#top) script also
validates and classifies rRNA sequences, but uses blastn to do
single-sequence comparisons in addition to using profiles.

The [`riboaligner`](documentation/riboaligner.md#top) script is used
to check if rRNA sequences are full length and do not extend past the
gene boundary.

The [`ribodbmaker`](documentation/ribodbmaker.md#top) script performs
a series of tests on input rRNA sequences to create a high quality dataset
of sequences that pass all tests.

## <a name="documentation"></a> Ribovore documentation 

* [Ribovore installation instructions](documentation/install.md#top)
* [`ribotyper` example usage, command-line options and unexpected feature information](documentation/ribotyper.md#top)
* [`ribosensor` example usage, command-line options and pass/fail criteria](documentation/ribosensor.md#top)
* [`riboaligner` example usage, command-line options and length classes](documentation/riboaligner.md#top)
* [`ribodbmaker` example usage and command-line options](documentation/ribodbmaker.md#top)
* [Ribovore model information](documentation/models.md#top)

---

## Reference <a name="reference"></a>
* The recommended citation for using ribovore is:
  Alejandro A. Schaffer, Richard McVeigh, Barbara Robbertse,
  Conrad L. Schoch, Anjanette Johnston, Beverly Underwood, Ilene Karsch-Mizrachi, Eric P.
  Nawrocki; *Ribovore: ribosomal RNA sequence analysis for GenBank submissions and database curation*;
  in preparation (to be uploaded to bioRxiv in Feb 2021);

---

#### Questions, comments or feature requests? Send a mail to eric.nawrocki@nih.gov.
