#!/usr/bin/perl
#
# version: 1.0.5
#
# ribo.pm
# Eric Nawrocki
# EPN, Fri May 12 09:48:21 2017
# 
# Perl module used by riboaligner, ribodbmaker, ribosensor,
# ribotest and ribotyper, which contains subroutines called by
# those scripts.

use strict;
use warnings;

my $ribo_sequip_dir = $ENV{"RIBOSEQUIPDIR"};
if(! defined $ribo_sequip_dir) { 
  die "ERROR, the environment variable \$RIBOSEQUIPDIR is not set, see ribovore/documentation/install.md";
}
if(! -d $ribo_sequip_dir) { 
  die "ERROR, the directory specified by the environment variable \$RIBOSEQUIPDIR does not exist, see ribovore/documentation/install.md";
}

# require the specific sequip modules in RIBOSEQUIPDIR in case user has another 
# package installed that uses a (potentially different version) of sequip (e.g. VADR)
require $ribo_sequip_dir . "/sqp_opts.pm";
require $ribo_sequip_dir . "/sqp_ofile.pm";
require $ribo_sequip_dir . "/sqp_seq.pm";
require $ribo_sequip_dir . "/sqp_seqfile.pm";
require $ribo_sequip_dir . "/sqp_utils.pm";

#
# List of subroutines:
#
# Parsing files:
# ribo_CountAmbiguousNucleotidesInSequenceFile
# ribo_ParseSeqstatFile 
# ribo_ParseSeqstatCompTblFile
# ribo_ParseRAModelinfoFile
# ribo_ParseQsubFile
# ribo_ParseLogFileForParallelTime
# ribo_ParseCmsearchFileForTotalCpuTime
# ribo_ParseCmalignFileForCpuTime
# ribo_ParseUnixTimeOutput
# ribo_ProcessSequenceFile 
#
# Infernal and rRNA_sensor related functions
# ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn
# ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation
# ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnWrapper
# ribo_MergeAlignmentsAndReorder
# ribo_WaitForFarmJobsToFinish
# 
# Miscellaneous utility functions:
# ribo_ConvertFetchedNameToAccVersion
# ribo_SumSeqlenGivenArray
# ribo_InitializeHashToEmptyString
# ribo_InitializeHashToZero
# ribo_NseBreakdown
# ribo_WriteCommandScript
# ribo_RemoveListOfDirsWithRmrf
# ribo_WriteAcceptFile
# ribo_CheckForTimeExecutable
# ribo_ParseStoredIndiCmFileName
#
# DuplicateRegion filter (ribotyper) null threshold table:
# ribo_DupfilterBlastnParams
# ribo_DupfilterNullLoad
# ribo_DupfilterAssertBlastnParams
# ribo_DupfilterOrientPair
# ribo_DupfilterRoundUp
# ribo_DupfilterNullLookupCell
# ribo_DupfilterNullThreshold
# ribo_DupfilterIsSignificant
#
#################################################################
# Subroutine : ribo_CountAmbiguousNucleotidesInSequenceFile()
# Incept:      EPN, Tue May 29 14:51:35 2018
#
# Purpose:     Use esl-seqstat to determine the number of ambiguous
#              nucleotides in each sequence in a sequence file.
#              
# Arguments: 
#   $seqstat_exec: path to esl-seqstat executable
#   $seq_file:     sequence file to process
#   $seqstat_file: path to esl-seqstat output to create
#   $seqnambig_HR: ref to hash of number of ambiguous nucleotides per sequence, filled here
#   $opt_HHR:      reference to 2D hash of cmdline options
#   $FH_HR:        REF to hash of file handles, including "cmd"
# 
# Returns:     number of sequences with 1 or more ambiguous nucleotides
#              fills %{$seqnambig_HR}.
#
# Dies:        If esl-seqstat call fails
#
################################################################# 
sub ribo_CountAmbiguousNucleotidesInSequenceFile { 
  my $nargs_expected = 6;
  my $sub_name = "ribo_CountAmbiguousNucleotidesInSequenceFile()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($seqstat_exec, $seq_file, $seqstat_file, $seqnambig_HR, $opt_HHR, $FH_HR) = (@_);

  utl_RunCommand($seqstat_exec . " --dna --comptbl $seq_file > $seqstat_file", opt_Get("-v", $opt_HHR), 0, $FH_HR);

  # parse esl-seqstat file to get lengths
  return ribo_ParseSeqstatCompTblFile($seqstat_file, $seqnambig_HR, $FH_HR);
}

#################################################################
# Subroutine : ribo_ParseSeqstatFile()
# Incept:      EPN, Wed Dec 14 16:16:22 2016
#
# Purpose:     Parse an esl-seqstat -a output file.
#              
# Arguments: 
#   $seqstat_file:            file to parse
#   $max_targetname_length_R: REF to the maximum length of any target name, updated here, can be undef
#   $max_length_length_R:     REF to the maximum length of string-ized length of any target seq, updated here, can be undef
#   $nseq_R:                  REF to the number of sequences read, updated here
#   $seqorder_AR:             REF to array of sequences in order to fill here
#   $seqidx_HR:               REF to hash of sequence indices to fill here
#   $seqlen_HR:               REF to hash of sequence lengths to fill here
#   $FH_HR:                   REF to hash of file handles, including "cmd"
#
# Returns:     Total number of nucleotides read (summed length of all sequences). 
#              Fills %{$seqidx_HR} and %{$seqlen_HR} and updates 
#              $$max_targetname_length_R, $$max_length_length_R, and $$nseq_R.
# 
# Dies:        If the sequence file has two sequences with identical names.
#              Error message will list all duplicates.
#              If no sequences were read.
#
################################################################# 
sub ribo_ParseSeqstatFile { 
  my $nargs_expected = 8;
  my $sub_name = "ribo_ParseSeqstatFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqstat_file, $max_targetname_length_R, $max_length_length_R, $nseq_R, $seqorder_AR, $seqidx_HR, $seqlen_HR, $FH_HR) = @_;

  open(IN, $seqstat_file) || ofile_FileOpenFailure($seqstat_file, $sub_name, $!, "reading", $FH_HR);

  my $nread = 0;            # number of sequences read
  my $tot_length = 0;       # summed length of all sequences
  my $targetname_length;    # length of a target name
  my $seqlength_length;     # length (number of digits) of a sequence length
  my $targetname;           # a target name
  my $length;               # length of a target
  my %seqdups_H = ();       # key is a sequence name that exists more than once in seq file, value is number of occurences
  my $at_least_one_dup = 0; # set to 1 if we find any duplicate sequence names

  # parse the seqstat -a output 
  # sequences must have non-empty names (else esl-seqstat call would have failed)
  # lengths must be >= 0 (lengths of 0 are okay)
  while(my $line = <IN>) { 
    # = lcl|dna_BP331_0.3k:467     1232 
    # = lcl|dna_BP331_0.3k:10     1397 
    # = lcl|dna_BP331_0.3k:1052     1414 
    chomp $line;
    #print $line . "\n";
    if($line =~ /^\=\s+(\S+)\s+(\d+)/) { 
      $nread++;
      ($targetname, $length) = ($1, $2);
      if(exists($seqidx_HR->{$targetname})) { 
        if(exists($seqdups_H{$targetname})) { 
          $seqdups_H{$targetname}++;
        }
        else { 
          $seqdups_H{$targetname} = 2;
        }
        $at_least_one_dup = 1;
      }
        
      push(@{$seqorder_AR}, $targetname);
      $seqidx_HR->{$targetname} = $nread;
      $seqlen_HR->{$targetname} = $length;
      $tot_length += $length;

      $targetname_length = length($targetname);
      if((defined $max_targetname_length_R) && ($targetname_length > $$max_targetname_length_R)) { 
        $$max_targetname_length_R = $targetname_length;
      }

      $seqlength_length  = length($length);
      if((defined $max_length_length_R) && ($seqlength_length > $$max_length_length_R)) { 
        $$max_length_length_R = $seqlength_length;
      }

    }
  }
  close(IN);
  if($nread == 0) { 
    ofile_FAIL("ERROR in $sub_name, did not read any sequence lengths in esl-seqstat file $seqstat_file, did you use -a option with esl-seqstat", 1, $FH_HR);
  }
  if($at_least_one_dup) { 
    my $i = 1;
    my $die_string = "\nERROR, not all sequences in input sequence file have a unique name. They must.\nList of sequences that occur more than once, with number of occurrences:\n";
    foreach $targetname (sort keys %seqdups_H) { 
      $die_string .= "\t($i) $targetname $seqdups_H{$targetname}\n";
      $i++;
    }
    $die_string .= "\n";
    ofile_FAIL($die_string, 1, $FH_HR);
  }

  $$nseq_R = $nread;

  return $tot_length;
}

#################################################################
# Subroutine : ribo_ParseSeqstatCompTblFile()
# Incept:      EPN, Tue May 29 14:55:18 2018
#
# Purpose:     Parse an esl-seqstat --comptbl output file.
#              
# Arguments: 
#   $seqstat_file:  file to parse
#   $seqnambig_HR:  REF to hash of number of ambiguities in each sequence, to fill here 
#
# Returns:     Total number of sequences with >= 1 ambiguous nucleotide.
# 
# Dies:        Never
#
################################################################# 
sub ribo_ParseSeqstatCompTblFile { 
  my $nargs_expected = 3;
  my $sub_name = "ribo_ParseSeqstatCompTblFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqstat_file, $seqnambig_HR, $FH_HR) = @_;

  open(IN, $seqstat_file) || ofile_FileOpenFailure($seqstat_file, $sub_name, $!, "reading", $FH_HR);

  my $nread = 0;            # number of sequences read
  my $nread_w_ambig = 0;    # summed length of all sequences
  my $seqname = undef;      # a sequence name
  my $nA;                   # number of As
  my $nC;                   # number of Cs
  my $nG;                   # number of Gs
  my $nT;                   # number of Ts
  my $L;                    # length of the sequence
  my $nambig;               # number of ambiguities           
  my %seqdups_H = ();       # key is a sequence name that exists more than once in seq file, value is number of occurences
  my $at_least_one_dup = 0; # set to 1 if we find any duplicate sequence names

  # parse the seqstat --comptbl output 
  while(my $line = <IN>) { 
    ## Sequence name                Length      A      C      G      T
    ##----------------------------- ------ ------ ------ ------ ------
    #gi|675602128|gb|KJ925573.1|       500    148     98    112    142
    #gi|219812015|gb|FJ552229.1|       796    193    209    244    150
    #gi|675602352|gb|KJ925797.1|       500    149    103    126    122

    chomp $line;
    #print $line . "\n";
    if($line =~ /^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) { 
      $nread++;
      ($seqname, $L, $nA, $nC, $nG, $nT) = ($1, $2, $3, $4, $5, $6);
      $nambig = $L - ($nA + $nC + $nG + $nT);
      if($nambig > 0) { $nread_w_ambig++; }
      $seqnambig_HR->{$seqname} = $nambig;
    }
    elsif($line !~ m/^\#/) { 
      ofile_FAIL("ERROR in $sub_name, unable to parse esl-seqstat --comptbl line $line from file $seqstat_file", 1, $FH_HR);
    }
  }
  close(IN);

  return $nread_w_ambig;
}

#################################################################
# Subroutine : ribo_ParseRAModelinfoFile()
# Incept:      EPN, Fri Oct 20 14:17:53 2017
#
# Purpose:     Parse a riboaligner modelinfo file, and 
#              fill information in @{$family_order_AR}, %{$family_modelname_HR}.
# 
#              
# Arguments: 
#   $modelinfo_file:       file to parse
#   $env_ribo_dir:         directory in which CM files should be found, if undef, should be full path
#   $family_order_AR:      reference to array of family names, in order read from file, FILLED HERE
#   $family_modelfile_HR:  reference to hash, key is family name, value is path to model, FILLED HERE 
#   $family_modellen_HR:   reference to hash, key is family name, value is consensus model length, FILLED HERE
#   $family_rtname_HAR     reference to hash, key is family name, value is array of ribotyper model 
#                          names to align with this model, FILLED HERE
#   $opt_i_used:           '1' if -i used to specify non-default modelinfo file, else '0'
#   $FH_HR:                ref to hash of file handles
#
# Returns:     void; 
#
################################################################# 
sub ribo_ParseRAModelinfoFile { 
  my $nargs_expected = 8;
  my $sub_name = "ribo_ParseRAModelinfoFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($modelinfo_file, $env_ribo_dir, $family_order_AR, $family_modelfile_HR, $family_modellen_HR, $family_rtname_HAR, $opt_i_used, $FH_HR) = @_;

  open(IN, $modelinfo_file) || ofile_FileOpenFailure($modelinfo_file, $sub_name, $!, "reading", $FH_HR);

  my %family_exists_H = ();

  # determine directory that $modelinfo_file exists in if -i used, all models must 
  # either be in this directory or in $env_ribo_dir
  my $non_df_modelinfo_dir = undef; # directory with modelinfo file, if -i used
  if($opt_i_used) { 
    $non_df_modelinfo_dir = ribo_GetDirPath($modelinfo_file);
  }
  my $in_df;    # true if model file exists in default model dir
  my $in_nondf; # true if model file exists in non-default model dir
  my $df_model_file = undef;
  my $non_df_model_file = undef;

  while(my $line = <IN>) { 
    ## each line has information on 1 family and at least 4 tokens: 
    ## token 1: family.domain name in ribotyper output files, referred to as the 'family' below (e.g. SSU.Bacteria)
    ## token 2: CM file name for this family
    ## token 3: integer, consensus length for the CM for this family
    ## token 4 to N: names of ribotyper models (e.g. SSU_rRNA_archaea) for which we'll use this model to align
    #SSU.Archaea RF01959.cm SSU_rRNA_archaea
    #SSU.Bacteria RF00177.cm SSU_rRNA_bacteria SSU_rRNA_cyanobacteria
    chomp $line; 
    if($line !~ /^\#/ && $line =~ m/\w/) { 
      $line =~ s/^\s+//; # remove leading whitespace
      $line =~ s/\s+$//; # remove trailing whitespace
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) < 4) { 
        ofile_FAIL("ERROR in $sub_name, less than 4 tokens found on line $line of $modelinfo_file", 1, $FH_HR);  
      }
      my $family    = $el_A[0];
      my $modelfile = $el_A[1];
      my $modellen  = $el_A[2];
      my @rtname_A = ();
      for(my $i = 3; $i < scalar(@el_A); $i++) { 
        if($el_A[$i] =~ /[\)\(]/) { 
          ofile_FAIL("ERROR in $sub_name, ribotyper model name $el_A[$i] has '(' and/or ')', but these characters are not allowed in model names", 1, $FH_HR);  
        }
        push(@rtname_A, $el_A[$i]);
      }
      if(defined $family_exists_H{$family}) {
        ofile_FAIL("ERROR in $sub_name, family $family (first token) exists in more than one line in $modelinfo_file", 1, $FH_HR);  
      }
      # make sure that $modelfile exists, either in $env_ribo_dir or, if
      # -i was used, in the same directory that $modelinfo_file is in
      $df_model_file = $env_ribo_dir . $modelfile;
      if($opt_i_used) {   
        $non_df_model_file = $non_df_modelinfo_dir . $modelfile;
        $in_nondf = utl_FileValidateExistsAndNonEmpty($non_df_model_file, undef, $sub_name, 0, $FH_HR); # don't die if it doesn't exist
        $in_df    = utl_FileValidateExistsAndNonEmpty($df_model_file,     undef, $sub_name, 0, $FH_HR); # don't die if it doesn't exist
        # if it exists in both places, use the -i specified version
        if(($in_nondf == 0) && ($in_df == 0)) { 
          ofile_FAIL("ERROR in $sub_name, looking for model file $modelfile, did not find it in the two places it's looked for:\ndirectory $non_df_modelinfo_dir (where model info file specified with -i is) AND\ndirectory $env_ribo_dir (default model directory)\n", 1, $FH_HR);
        }
        elsif(($in_nondf == -1) && ($in_df == 0)) { 
          ofile_FAIL("ERROR in $sub_name, looking for model file $modelfile, it exists as $non_df_model_file but is empty", 1, $FH_HR);
        }
        elsif(($in_nondf == 0) && ($in_df == -1)) { 
          ofile_FAIL("ERROR in $sub_name, looking for model file $modelfile, it exists as $df_model_file but is empty", 1, $FH_HR);
        }
       elsif($in_nondf == 1) { 
          $modelfile = $non_df_model_file;
        }
        elsif($in_df == 1) { 
          $modelfile = $df_model_file;
        }
        else { 
          ofile_FAIL("ERROR in $sub_name, looking for model file, unexpected situation (in_nondf: $in_nondf, in_df: $in_df)\n", 1, $FH_HR);
        }
      }     
      else { # $opt_i_used is FALSE, -i not used, models must be in $env_ribo_dir
        utl_FileValidateExistsAndNonEmpty($df_model_file, "model file name read from default model info file", $sub_name, 1, $FH_HR); # die if it doesn't exist
        $modelfile = $df_model_file;
      }
      push(@{$family_order_AR}, $family);
      $family_modelfile_HR->{$family}  = $modelfile;
      $family_modellen_HR->{$family}   = $modellen;
      @{$family_rtname_HAR->{$family}} = (@rtname_A);
      $family_exists_H{$family} = 1;
    }
  }


  close(IN);

  return;
}

#################################################################
# Subroutine : ribo_ParseQsubFile()
# Incept:      EPN, Mon Jul  9 10:30:41 2018
#
# Purpose:     Parse a file that specifies the qsub command to use
#              when submitting jobs to the farm. The file should 
#              have exactly 2 non-'#' prefixed lines. Chomp each
#              and return them.
#              
# Arguments: 
#   $qsub_file:  file to parse
#   $FH_HR:      REF to hash of file handles
#
# Returns:     2 values:
#              $qsub_prefix: string that is the qsub command prior to the 
#                            actual cmsearch/cmalign command
#              $qsub_suffix: string that is the qsub command after the 
#                            actual cmsearch/cmalign command
# 
# Dies:        If we can't parse the qsub file because it is not
#              in the correct format.
#
################################################################# 
sub ribo_ParseQsubFile { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseQsubFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($qsub_file, $FH_HR) = @_;

  open(IN, $qsub_file) || ofile_FileOpenFailure($qsub_file, $sub_name, $!, "reading", $FH_HR);

  my $qsub_prefix_line = undef;
  my $qsub_suffix_line = undef;
  while(my $line = <IN>) { 
    if($line !~ m/^\#/) { 
      chomp $line;
      if   (! defined $qsub_prefix_line) { $qsub_prefix_line = $line; }
      elsif(! defined $qsub_suffix_line) { $qsub_suffix_line = $line; }
      else { # both $qsub_prefix_line and $qsub_suffix_line are defined, this shouldn't happen
        ofile_FAIL("ERROR in $sub_name, read more than 2 non-# prefixed lines in file $qsub_file:\n$line\n", $?, $FH_HR);
      }
    }
  }
  close(IN);
  
  if(! defined $qsub_prefix_line) { 
    ofile_FAIL("ERROR in $sub_name, read zero non-# prefixed lines in file $qsub_file, but expected 2", $?, $FH_HR);
  }
  if(! defined $qsub_suffix_line) { 
    ofile_FAIL("ERROR in $sub_name, read only one non-# prefixed lines in file $qsub_file, but expected 2", $?, $FH_HR);
  }

  return($qsub_prefix_line, $qsub_suffix_line);
}

#################################################################
# Subroutine : ribo_ParseLogFileForParallelTime()
# Incept:      EPN, Tue Oct  9 10:24:09 2018
#
# Purpose:     Parse a log file output from ribotyper or riboaligner
#              to get CPU time. 
#              
# Arguments: 
#   $log_file:  file to parse
#   $FH_HR:     REF to hash of file handles
#
# Returns:     Number of seconds read from special lines showing
#              time of multiple jobs due to -p option.
#
################################################################# 
sub ribo_ParseLogFileForParallelTime { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseQsubFileForParallelTime";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($log_file, $FH_HR) = @_;

  open(IN, $log_file) || ofile_FileOpenFailure($log_file, $sub_name, $!, "reading", $FH_HR);

  my $tot_secs = 0.;
  while(my $line = <IN>) { 
    # Elapsed time below does not include summed elapsed time of multiple jobs [-p], totalling 00:01:37.55  (hh:mm:ss) (does not include waiting time)
    if($line =~ /summed elapsed time.+totalling\s+(\d+)\:(\d+)\:(\d+\.\d+)/) { 
      my ($hours, $minutes, $seconds) = ($1, $2, $3);
      $tot_secs += (3600. * $hours) + (60. * $minutes) + $seconds;
    }
  }
  close(IN);

  return $tot_secs;
}

#################################################################
# Subroutine : ribo_ParseCmsearchFileForTotalCpuTime()
# Incept:      EPN, Tue Oct  9 15:12:34 2018
#
# Purpose:     Parse a cmsearch output file to get total number of
#              CPU seconds elapsed in lines starting with
#              "# Total CPU time" which are only printed if the 
#              --verbose option is used to cmsearch.
#              
# Arguments: 
#   $out_file:  file to parse
#   $FH_HR:     REF to hash of file handles
#
# Returns:     Summed number of elapsed seconds read from >= 1 Total CPU time lines.
#
################################################################# 
sub ribo_ParseCmsearchFileForTotalCpuTime { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseCmsearchFileForTotalCpuTime";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($out_file, $FH_HR) = @_;

  open(IN, $out_file) || ofile_FileOpenFailure($out_file, $sub_name, $!, "reading", $FH_HR);

  my $tot_secs = 0.;
  while(my $line = <IN>) { 
    # Total CPU time:1.43u 0.19s 00:00:01.62 Elapsed: 00:00:01.70
    if($line =~ /^# Total CPU time.+Elapsed\:\s+(\d+)\:(\d+)\:(\d+\.\d+)/) { 
      my ($hours, $minutes, $seconds) = ($1, $2, $3);
      $tot_secs += (3600. * $hours) + (60. * $minutes) + $seconds;
    }
  }
  close(IN);

  return $tot_secs;
}


#################################################################
# Subroutine : ribo_ParseCmalignFileForCpuTime()
# Incept:      EPN, Wed Oct 10 09:20:32 2018
#
# Purpose:     Parse a cmalign output file to get total number of
#              CPU seconds elapsed in lines starting with
#              "# CPU time".
#              
# Arguments: 
#   $out_file:  file to parse
#   $FH_HR:     REF to hash of file handles
#
# Returns:     Summed number of elapsed seconds read from >= 1 Total CPU time lines.
#
################################################################# 
sub ribo_ParseCmalignFileForCpuTime { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseCmalignFileForCpuTime";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($out_file, $FH_HR) = @_;

  open(IN, $out_file) || ofile_FileOpenFailure($out_file, $sub_name, $!, "reading", $FH_HR);

  my $tot_secs = 0.;
  while(my $line = <IN>) { 
    # CPU time: 6.72u 0.28s 00:00:07.00 Elapsed: 00:00:07.93
    if($line =~ /^# CPU time.+Elapsed\:\s+(\d+)\:(\d+)\:(\d+\.\d+)/) { 
      my ($hours, $minutes, $seconds) = ($1, $2, $3);
      $tot_secs += (3600. * $hours) + (60. * $minutes) + $seconds;
    }
  }
  close(IN);

  return $tot_secs;
}

#################################################################
# Subroutine : ribo_ParseUnixTimeOutput()
# Incept:      EPN, Mon Oct 22 14:58:18 2018
#
# Purpose:     Parse the output of 1 or more runs of Unix's 'time -p' 
#              (NOT THE 'time' SHELL BUILTIN, which has output 
#              that varies depending on the shell being run).
#              With -p, 'time' is supposed to output in a portable
#              format:
#              
#              From:
#              http://man7.org/linux/man-pages/man1/time.1.html
#              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#              -p     When in the POSIX locale, use the precise traditional format
#                 "real %f\nuser %f\nsys %f\n"
#
#              (with numbers in seconds) where the number of decimals in the
#              output for %f is unspecified but is sufficient to express the
#              clock tick accuracy, and at least one.
#              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
#              So for example:
# 
#              real 0.52
#              user 0.04
#              sys 0.08
#              
# Arguments: 
#   $out_file:  file to parse
#   $FH_HR:     REF to hash of file handles
#
# Returns:     Summed number of elapsed seconds read from all 'real' lines.
#
################################################################# 
sub ribo_ParseUnixTimeOutput { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseUnixTimeOutput";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($out_file, $FH_HR) = @_;

  open(IN, $out_file) || ofile_FileOpenFailure($out_file, $sub_name, $!, "reading", $FH_HR);

  my $tot_secs = 0.;
  while(my $line = <IN>) { 
    # Total CPU time:1.43u 0.19s 00:00:01.62 Elapsed: 00:00:01.70
    if($line =~ /^real\s+(\d+\.\d+)/) { 
      my ($seconds) = ($1, $2);
      $tot_secs += $seconds;
    }
  }
  close(IN);

  return $tot_secs;
}

#################################################################
# Subroutine : ribo_ProcessSequenceFile()
# Incept:      EPN, Fri May 12 10:08:47 2017
#
# Purpose:     Use esl-seqstat to get the lengths of all sequences in a
#              FASTA or Stockholm formatted sequence file and fill
#              %{$seqidx_HR} and %{$seqlen_HR} where key is sequence
#              name, and value is index in file or sequence
#              length. Also update %{$width_HR} with maximum length of
#              sequence name (key: "target"), index (key: "index") and
#              length (key: "length").
#              
# Arguments: 
#   $seqstat_exec:   path to esl-seqstat executable
#   $seq_file:       sequence file to process
#   $seqstat_file:   path to esl-seqstat output to create
#   $seqorder_AR:    ref to array of sequences in order to fill here
#   $seqidx_HR:      ref to hash of sequence indices to fill here
#   $seqlen_HR:      ref to hash of sequence lengths to fill here
#   $width_HR:       ref to hash to fill with max widths (see Purpose), can be undef
#   $opt_HHR:        reference to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
# 
# Returns:     total number of nucleotides in all sequences read, 
#              fills %{$seqidx_HR}, %{$seqlen_HR}, and 
#              %{$width_HR} (partially)
#
# Dies:        If the sequence file has two sequences with identical names.
#              Error message will list all duplicates.
#              If no sequences were read.
#
################################################################# 
sub ribo_ProcessSequenceFile { 
  my $nargs_expected = 9;
  my $sub_name = "ribo_ProcessSequenceFile()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($seqstat_exec, $seq_file, $seqstat_file, $seqorder_AR, $seqidx_HR, $seqlen_HR, $width_HR, $opt_HHR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  utl_RunCommand($seqstat_exec . " --dna -a $seq_file > $seqstat_file", opt_Get("-v", $opt_HHR), 0, $FH_HR);
  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "seqstat", $seqstat_file, 0, 1, "esl-seqstat -a output for $seq_file");

  # parse esl-seqstat file to get lengths
  my $max_targetname_length = length("target"); # maximum length of any target name
  my $max_length_length     = length("length"); # maximum length of the string-ized length of any target
  my $nseq                  = 0; # number of sequences read
  my $tot_length = ribo_ParseSeqstatFile($seqstat_file, \$max_targetname_length, \$max_length_length, \$nseq, $seqorder_AR, $seqidx_HR, $seqlen_HR, $FH_HR); 

  if(defined $width_HR) { 
    $width_HR->{"target"} = $max_targetname_length;
    $width_HR->{"length"} = $max_length_length;
    $width_HR->{"index"}  = length($nseq);
    if($width_HR->{"index"} < length("#idx")) { $width_HR->{"index"} = length("#idx"); }
  }

  return $tot_length;
}

#################################################################
# Subroutine: ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn
# Incept:     EPN, Thu Jul  5 15:05:53 2018
#             EPN, Wed Oct 17 20:45:53 2018 [rRNA_sensor added]
#             EPN, Tue Oct  3 14:09:16 2023 [blastn added]
#
# Purpose:    Run cmsearch, cmalign, rRNA_sensor or blastn either 
#             locally or on the farm.
#
# Arguments:
#   $executable:     path to cmsearch or cmalign or rRNA_sensor executable
#   $time_path:      path to Unix time command (e.g. /usr/bin/time)
#   $cmfetch_path:   path to cmfetch executable
#   $qsub_prefix:    qsub command prefix to use when submitting to farm, undef to run locally
#   $qsub_suffix:    qsub command suffix to use when submitting to farm, undef to run locally
#   $opts:           options to provide to cmsearch or cmalign or rRNA_sensor or blastn arguments to use 
#   $info_HR:        ref to hash with output files and arguments for running 
#                    $program_choice (cmsearch/cmalign/rRNA_sensor_script).
#                    Validated by ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation()
#                    see comments for that subroutine for more details.
#   $opt_HHR:        ref to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:  void
# 
# Dies:     Never
#
#################################################################
sub ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn { 
  my $sub_name = "ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn()";
  my $nargs_expected = 9;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($executable, $time_path, $cmfetch_path, $qsub_prefix, $qsub_suffix, $opts, $info_HR, $opt_HHR, $ofile_info_HHR) = @_;

  # we can only pass $FH_HR to ofile_FAIL if that hash already exists
  my $FH_HR = (defined $ofile_info_HHR->{"FH"}) ? $ofile_info_HHR->{"FH"} : undef;

  # validate %{$info_HR}
  my $program_choice = ofile_RemoveDirPath($executable);
  ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation($program_choice, $info_HR, $opt_HHR, $ofile_info_HHR);

  # IN:seqfile, OUT-NAME:stdout, OUT-NAME:time and OUT-NAME:stderr are required key for all programs (cmsearch, cmalign and rRNA_sensor_script)
  my $seq_file        = $info_HR->{"IN:seqfile"};
  my $stdout_file     = $info_HR->{"OUT-NAME:stdout"}; # may be undef
  my $time_file       = $info_HR->{"OUT-NAME:time"};
  my $stderr_file     = $info_HR->{"OUT-NAME:stderr"};
  my $qcmdscript_file = $info_HR->{"OUT-NAME:qcmd"};
  my $tmp_stderr_file = $stderr_file . ".tmp"; # necessary because we need to process $tmp_stderr_file to get $time_file and $stderr_file
  my $tail_stderr_cmd = "tail -n 3 $tmp_stderr_file > $time_file"; # to create $time_file
  my $awk_stderr_cmd  = "awk 'n>=3 { print a[n%3] } { a[n%3]=\$0; n=n+1 }' $tmp_stderr_file > $stderr_file";
  my $rm_tmp_cmd      = "rm $tmp_stderr_file";
  
  # determine if we are running on the farm or locally
  my $cmd      = ""; # the command that runs cmsearch, cmalign or rRNA_sensor

  # determine if we have the appropriate paths defined in %{$info_HR} 
  # depending on if $executable is "cmalign" or "cmsearch" or "rRNA_sensor_script"
  # and run the program
  if($executable =~ /cmsearch$/) { 
    my ($model_file, $model_name, $do_fetch) = ribo_ParseStoredIndiCmFileName($info_HR->{"IN:modelfile"});
    my $tblout_file = $info_HR->{"OUT-NAME:tblout"};
    my $fetch_cmd = "";
    if($do_fetch) {
      $fetch_cmd = "cmfetch $model_file $model_name | ";
      $model_file = "-";
    }
    # Not all implementations of 'time' accept -o (Mac OS/X's sometimes doesn't)
    #$cmd = "$time_path -p -o $time_file $executable $opts --verbose --tblout $tblout_file $model_file $seq_file > $stdout_file 2> $stderr_file";
    if(defined $time_path) { 
      $cmd = "$time_path -p $fetch_cmd $executable $opts --verbose --tblout $tblout_file $model_file $seq_file > $stdout_file 2> $tmp_stderr_file;$tail_stderr_cmd;$awk_stderr_cmd;$rm_tmp_cmd;"
    }
    else {
      $cmd = "$fetch_cmd $executable $opts --verbose --tblout $tblout_file $model_file $seq_file > $stdout_file 2> $stderr_file"
    }
  }
  elsif($executable =~ /cmalign$/) { 
    my $model_file    = $info_HR->{"IN:modelfile"};
    my $i_file        = $info_HR->{"OUT-NAME:ifile"};
    my $stk_file      = $info_HR->{"OUT-NAME:stk"};
    my $el_file       = (opt_IsUsed("--glocal", $opt_HHR)) ? undef : $info_HR->{"OUT-NAME:elfile"};
    my $el_opt        = (opt_IsUsed("--glocal", $opt_HHR)) ? ""    : "--elfile $el_file ";

    # Not all implementations of 'time' accept -o (Mac OS/X's sometimes doesn't)
    #$cmd = "$time_path -p -o $time_file $executable $opts --ifile $i_file $el_opt -o $stk_file $model_file $seq_file > $stdout_file 2> $stderr_file";
    if(defined $time_path) { 
      $cmd = "$time_path -p $executable $opts --ifile $i_file $el_opt -o $stk_file $model_file $seq_file > $stdout_file 2> $tmp_stderr_file;$tail_stderr_cmd;$awk_stderr_cmd;$rm_tmp_cmd;"
    }
    else {
      $cmd = "$executable $opts --ifile $i_file $el_opt -o $stk_file $model_file $seq_file > $stdout_file 2> $stderr_file";
    }
  }
  elsif($executable =~ /rRNA_sensor_script$/) { 
    my $minlen     = $info_HR->{"minlen"};
    my $maxlen     = $info_HR->{"maxlen"};
    my $classpath  = $info_HR->{"OUT-DIR:classpath"};
    my $classlocal = ofile_RemoveDirPath($classpath);
    my $minid      = $info_HR->{"minid"};
    my $maxevalue  = $info_HR->{"maxevalue"};
    my $ncpu       = $info_HR->{"ncpu"};
    my $outdir     = $info_HR->{"OUT-NAME:outdir"};
    my $blastdb    = $info_HR->{"blastdb"};
    # Not all implementations of 'time' accept -o (Mac OS/X's sometimes doesn't)
    #$cmd = "$time_path -p -o $time_file $executable $minlen $maxlen $seq_file $classlocal $minid $maxevalue $ncpu $outdir $blastdb > $stdout_file 2> $stderr_file";
    if(defined $time_path) { 
      $cmd = "$time_path -p $executable $minlen $maxlen $seq_file $classlocal $minid $maxevalue $ncpu $outdir $blastdb > $stdout_file 2> $tmp_stderr_file;$tail_stderr_cmd;$awk_stderr_cmd;$rm_tmp_cmd"
    }
    else {
      $cmd = "$executable $minlen $maxlen $seq_file $classlocal $minid $maxevalue $ncpu $outdir $blastdb > $stdout_file 2> $stderr_file"
    }
  }
  elsif($executable =~ /blastn$/) { 
    my $blastdb     = $info_HR->{"blastdb"};
    my $tblout_file = $info_HR->{"OUT-NAME:tblout"};
    # Not all implementations of 'time' accept -o (Mac OS/X's sometimes doesn't)
    if(defined $time_path) { 
      $cmd = "$time_path -p $executable $opts -num_threads 1 -query $seq_file -db $blastdb -outfmt 6 -out $tblout_file 2> $tmp_stderr_file;$tail_stderr_cmd;$awk_stderr_cmd;$rm_tmp_cmd"
    }
    else {
      $cmd = "$executable $opts -num_threads 1 -query $seq_file -db $blastdb -outfmt 6 -out $tblout_file 2> $stderr_file";
    }
  }

  if((defined $qsub_prefix) && (defined $qsub_suffix)) { 
    # write a script to execute on the cluster and execute it

    # replace ![jobname]! with $jobname
    my $jobname = "j" . ofile_RemoveDirPath($seq_file);
    my $qsub_cmd = $qsub_prefix . "sh $qcmdscript_file" . $qsub_suffix;
    $qsub_cmd =~ s/\!\[jobname\]\!/$jobname/g;

    # create the shell script file with the cmsearch/cmalign/rRNA_sensor command $cmd
    ribo_WriteCommandScript($qcmdscript_file, $cmd, $FH_HR);
    utl_RunCommand($qsub_cmd, opt_Get("-v", $opt_HHR), 0, $FH_HR);
  }
  else {
    # run command locally and wait for it to complete
    utl_RunCommand($cmd, opt_Get("-v", $opt_HHR), 0, $FH_HR);
    # Exit if an expected file does not exists or is empty, it should always exist and be non-empty.
    # We had to add this shortly before the 1.0 release because if a cmsearch cmd fails, the 'time'
    # command will not return a non-0 exit status so the program will not exit. By enforcing this
    # file exists and is non-empty we catch this situation because cmsearch tblout will be empty.
    my $expected_out_file = undef;
    if(($executable =~ /cmsearch$/) || ($executable =~ /cmalign$/)) {
      if($executable =~ /cmsearch$/) { 
        $expected_out_file = $info_HR->{"OUT-NAME:tblout"};
      }
      elsif($executable =~ /cmalign$/) {
        $expected_out_file = $info_HR->{"OUT-NAME:stk"};
      }
      elsif($executable =~ /blastn$/) {
        $expected_out_file = $info_HR->{"OUT-NAME:stdout"};
      }
      # we don't check for output file for rRNA_sensor because it may exist even if command failed
      # we'll catch if it failed later when we try to parse the output (program should exit)
      utl_FileValidateExistsAndNonEmpty($expected_out_file, "expected output file from command $cmd", $sub_name, 1, $FH_HR);
    }
  }
  # else create the qsub cmd script file (the file with the actual cmsearch/cmalign/rRNA_sensor command)
  # we will submit a job to the farm that will execute this qsub cmd script file (previously we just put the
  # command 

  return;
}

#################################################################
# Subroutine:  ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation()
# Incept:      EPN, Thu Oct 18 12:32:18 2018
#
# Purpose:     Validate that we can run cmsearch, cmalign, rRNA_sensor
#              or blastn by checking that %{$info_HR} is valid.
#
#              %{$info_HR} uses some key name conventions to include
#              extra information that pertains to parallel mode only
#              (-p). 
#              
#              Keys beginning with 'IN:' are input files and we
#              check to make sure they exist in this subroutine.
#
#              Keys beginning with 'OUT-NAME:' and 'OUT-DIR:' are
#              OUTput files that will have a integer (actually ".<d>")
#              appended to their file NAMEs (if OUT-NAME) or DIRectory
#              names (if OUT-DIR), one per job run in
#              parallel. When all jobs are complete the individual
#              files are concatenated into one file named as the value
#              of $info_HR->{"OUT-{NAME,DIR}:<s>"}.
#
# Arguments: 
#  $program_choice:  "cmalign" or "cmsearch" or "rRNA_sensor_script" or "blastn"
#  $info_HR:         ref to hash with output files and arguments for running 
#                    $program_choice (cmsearch/cmalign/rRNA_sensor_script).
#
#                    if "cmsearch", keys must be: 
#                       "IN:seqfile":         name of input master sequence file
#                       "IN:modelfile":       name of input model (CM) file 
#                       "OUT-NAME:tblout":    name of tblout output file (--tblout)
#                       "OUT-NAME:stdout":    name of stdout output file
#                       "OUT-NAME:time":      path to time output file
#                       "OUT-NAME:stderr":    path to stderr output file
#                       "OUT-NAME:qcmd":      path to cmd script file for the qsub cmd
#
#                    if "cmalign", keys must be:
#                       "IN:seqfile":       name of input master sequence file
#                       "IN:modelfile":     name of input model (CM) file 
#                       "OUT-NAME:ifile":   name of ifile output file (--ifile)
#                       "OUT-NAME:elfile":  name of elfile output file (--elfile)
#                       "OUT-NAME:stk":     name of alignment output file (-o)
#                       "IN:seqlist":       name of file listing all sequences in "IN:seqfile";
#                       "OUT-NAME:stdout":  name of stdout output file
#                       "OUT-NAME:time":    path to time output file
#                       "OUT-NAME:stderr":  path to stderr output file
#                       "OUT-NAME:qcmd":    path to cmd script file for the qsub cmd
#
#                    if "rRNA_sensor_script", keys must be:
#                       "IN:seqfile":        name of master sequence file
#                       "minlen":            minimum length of sequence to allow (cmdline arg 1)
#                       "maxlen":            maximum length of sequence to allow (cmdline arg 2)
#                       "OUT-DIR:classpath": path to output file with class definitions (file name (without path) will be cmdline arg 4)
#                       "OUT-DIR:lensum":    path to length summary file 
#                       "OUT-DIR:blastout":  path to blast output file
#                       "minid":             min blast %id to allow              (cmdline arg 5)
#                       "maxevalue":         max blast E-value to allow          (cmdline arg 6)
#                       "ncpu":              number of CPUs to use               (cmdline arg 7)
#                       "OUT-NAME:outdir"    name of output diretory             (cmdline arg 8)
#                       "blastdb":           name of blast db                    (cmdline arg 9)
#                       "OUT-NAME:stdout":   name of stdout output file
#                       "OUT-NAME:time":     path to time output file
#                       "OUT-NAME:stderr":   path to stderr output file
#                       "OUT-NAME:qcmd":     path to cmd script file for the qsub cmd
#
#                    if "blastn", keys must be:
#                       "IN:seqfile":        name of master sequence file
#                       "blastdb":           name of blast db                    (cmdline arg 9)
#                       "OUT-NAME:tblout":   name of tabular output file
#                       "OUT-NAME:time":     path to time output file
#                       "OUT-NAME:stderr":   path to stderr output file
#                       "OUT-NAME:qcmd":     path to cmd script file for the qsub cmd
#
#  $opt_HHR:         REF to 2D hash of option values, see top of seqp_opts.pm for description
#  $ofile_info_HHR:  REF to 2D hash of output file information
#
# Returns: 2 values: 
#          $wait_key:   key in $info_HR for which $info_HR->{$wait_key} is the file
#                       to look for $wait_str in to indicate the job is finished
#          $wait_str:   string in the final line of $info_HR->{$wait_key} that indicates
#                       a job is finished.
# 
# Dies: If program_choice is invalid, a required info_key is not set, or an input file does not exist
#
################################################################# 
sub ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation { 
  my $sub_name = "ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($program_choice, $info_HR, $opt_HHR, $ofile_info_HHR) = @_;

  my $wait_key   = undef;
  my $wait_str   = undef;
  my @reqd_keys_A = ();
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  # determine if we have the appropriate paths defined in %{$info_HR} 
  # depending on if $program_choice is "cmalign" or "cmsearch" or "rRNA_sensor_script"
  if($program_choice eq "cmsearch") { 
    $wait_key = "OUT-NAME:tblout";
    $wait_str = "[ok]";
    @reqd_keys_A = ("IN:seqfile", "IN:modelfile", "OUT-NAME:tblout", "OUT-NAME:stdout", "OUT-NAME:time", "OUT-NAME:stderr", "OUT-NAME:qcmd");
  }
  elsif($program_choice eq "cmalign") { 
    $wait_key = "OUT-NAME:stdout";
    $wait_str = "# CPU time:";
    @reqd_keys_A = ("IN:seqfile", "IN:modelfile", "OUT-NAME:stk", "OUT-NAME:ifile", "IN:seqlist", "OUT-NAME:stdout", "OUT-NAME:time", "OUT-NAME:stderr", "OUT-NAME:qcmd");
    if(! opt_Get("--glocal", $opt_HHR)) { 
      push(@reqd_keys_A, "OUT-NAME:elfile");
    }
  }
  elsif($program_choice eq "rRNA_sensor_script") { 
    $wait_key = "OUT-NAME:stdout";
    $wait_str = "Final output saved as";
    @reqd_keys_A = ("IN:seqfile", "minlen", "maxlen", "OUT-DIR:classpath", "OUT-DIR:lensum", "OUT-DIR:blastout", "minid", "maxevalue", "ncpu", "OUT-NAME:outdir", "blastdb", "OUT-NAME:stdout", "OUT-NAME:time", "OUT-NAME:stderr", "OUT-NAME:qcmd");
  }
  elsif($program_choice eq "blastn") { 
    $wait_key = "OUT-NAME:tblout";
    $wait_str = "Final output saved as";
    @reqd_keys_A = ("IN:seqfile", "blastdb", "OUT-NAME:tblout", "OUT-NAME:time", "OUT-NAME:stderr", "OUT-NAME:qcmd");
  }
  else { 
    ofile_FAIL("ERROR in $sub_name, chosen executable $program_choice is not cmsearch, cmalign, or rRNA_sensor", 1, $FH_HR);
  }
  # verify all keys exists, and that input files exist
  foreach my $key (@reqd_keys_A) { 
    if(! exists $info_HR->{$key}) { 
      ofile_FAIL("ERROR in $sub_name, executable is $program_choice but $key file not set", 1, $FH_HR); 
    }
    # if it is an input file, make sure it exists
    if($info_HR->{$key} =~ m/^IN:/) { 
      utl_FileValidateExistsAndNonEmpty($info_HR->{$key}, undef, $sub_name, 1, $FH_HR); 
    }
  }
  
  return($wait_key, $wait_str);
}

#################################################################
# Subroutine:  ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnWrapper()
# Incept:      EPN, Thu Jul  5 15:24:19 2018
#              EPN, Wed Oct 17 20:46:10 2018 [rRNA_sensor added]
#              EPN, Tue Oct  3 14:15:10 2023 [blastn added]
#
# Purpose:     Run one or more cmsearch, cmalign, rRNA_sensor or blastn jobs 
#              on the farm or locally, after possibly splitting up the input
#              sequence file. 
#              The following must all be valid options in opt_HHR:
#              -p, --nkb, -s, --wait, --errcheck, --keep, -v
#              See ribotyper for examples of these options.
#
# Arguments: 
#  $execs_HR:        ref to hash with paths to executables
#  $program_choice:  "cmalign" or "cmsearch" or "rRNA_sensor_script" or "blastn"
#  $qsub_prefix:     qsub command prefix to use when submitting to farm, if -p
#  $qsub_suffix:     qsub command suffix to use when submitting to farm, if -p
#  $seqlen_HR:       ref to hash of sequence lengths, key is sequence name, value is length
#  $progress_w:      width for outputProgressPrior output
#  $out_root:        output root for naming sequence files
#  $tot_nseq:        number of sequences in $seq_file
#  $tot_len_nt:      total length of all nucleotides in $seq_file
#  $opts:            string of cmsearch or cmalign options or rRNA_sensor arguments
#  $info_HR:         ref to hash with output files and arguments for running 
#                    $program_choice (cmsearch/cmalign/rRNA_sensor_script).
#                    Validated by ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation()
#                    see comments for that subroutine for more details.
#  $opt_HHR:         REF to 2D hash of option values, see top of sqp_opts.pm for description
#  $ofile_info_HHR:  REF to 2D hash of output file information
#
# Returns: $sum_cpu_plus_wait_secs:   '0' unless -p used.
#                           If -p used: this is an estimate on total number CPU
#                           seconds used required by all jobs summed together. This is
#                           more than actual CPU seconds, because, for example, if a
#                           job takes 1 seconds and we didn't check on until 10 
#                           seconds elapsed, then it will contribute 10 seconds to this total.
# 
# Dies: If an executable doesn't exist, or cmsearch command fails if we're running locally
################################################################# 
sub ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnWrapper { 
  my $sub_name = "ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnWrapper";
  my $nargs_expected = 13;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($execs_HR, $program_choice, $qsub_prefix, $qsub_suffix, $seqlen_HR, $progress_w, $out_root, $tot_nseq, $tot_len_nt, $opts, $info_HR, $opt_HHR, $ofile_info_HHR) = @_;

  my $FH_HR  = $ofile_info_HHR->{"FH"}; # for convenience
  my $log_FH = $ofile_info_HHR->{"FH"}{"log"}; # for convenience
  my $out_dir = ribo_GetDirPath($out_root);
  my $executable = undef; # path to the cmsearch or cmalign executable
  my $info_key   = undef; # a single info_HH 1D key
  my $wait_str   = undef; # string in output file that ribo_WaitForFarmJobsToFinish will check for to see if jobs are done
  my $wait_key   = undef; # outfile key that ribo_WaitForFarmJobsToFinish will use to check if jobs are done
  my $sum_cpu_plus_wait_secs = 0; # will be returned as '0' unless -p used
  my $njobs_finished = 0; 

  my $time_path = undef;
  if(defined $execs_HR->{"time"}) {
    $time_path = $execs_HR->{"time"};
  }
  my $cmfetch_path = undef;
  if(defined $execs_HR->{"cmfetch"}) {
    $cmfetch_path = $execs_HR->{"cmfetch"};
  }
  
  # validate %{$info_HR}
  ($wait_key, $wait_str) = ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastnValidation($program_choice, $info_HR, $opt_HHR, $ofile_info_HHR);
  $executable = $execs_HR->{$program_choice};

  if(! opt_Get("-p", $opt_HHR)) { 
    # run job locally
    ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn($executable, $time_path, $cmfetch_path, undef, undef, $opts, $info_HR, $opt_HHR, $ofile_info_HHR); # undefs: run locally
  }
  else { 
    my %wkr_outfiles_HA = (); # hash of arrays of output file names for all jobs, 
                              # these are files to concatenate or otherwise combine after all jobs are finished
    my %wkr_info_H = (); # hash of info for one worker's job

    # we need to split up the sequence file, and submit a separate set of cmsearch/cmalign/rRNA_sensor jobs for each file
    my $seq_file = $info_HR->{"IN:seqfile"};
    my $nfasta_created = sqf_FastaFileSplitRandomly($seq_file, $seqlen_HR, $out_dir, $tot_nseq, $tot_len_nt, opt_Get("--nkb", $opt_HHR) * 1000, opt_Get("-s", $opt_HHR), $ofile_info_HHR->{"FH"});

    # submit all jobs to the farm
    my @info_keys_A = sort keys (%{$info_HR});
    my $info_key;
    for(my $f = 1; $f <= $nfasta_created; $f++) { 
      my %wkr_info_H = ();
      my $seq_file_tail = ofile_RemoveDirPath($seq_file);
      my $wkr_seq_file  = $out_dir . "/" . $seq_file_tail . "." . $f;
      foreach $info_key (@info_keys_A) { 
        if($info_key eq "IN:seqfile") { # special case
          $wkr_info_H{$info_key} = $wkr_seq_file;
          # keep a list of these files, we'll remove them later
          push(@{$wkr_outfiles_HA{$info_key}}, $wkr_info_H{$info_key});
        }
        elsif($info_key =~ m/^OUT/) { 
          if($info_HR->{$info_key} eq "/dev/null") { 
            $wkr_info_H{$info_key} = "/dev/null";
          }
          elsif($info_key =~ m/^OUT-NAME/) { 
            $wkr_info_H{$info_key} = $info_HR->{$info_key} . "." . $f;
          }
          elsif($info_key =~ m/^OUT-DIR/) { 
            # need to put the .$f at end of dir path
            my $tmpdir  = ribo_GetDirPath($info_HR->{$info_key});
            $tmpdir =~ s/\/$//;
            my $tmpfile = ofile_RemoveDirPath($info_HR->{$info_key});
            $wkr_info_H{$info_key} = $tmpdir . "." . $f . "/" . $tmpfile;
          }
          else { 
            ofile_FAIL("ERROR unrecognized special prefix beginning with OUT in info_H key: $info_key", 1, $FH_HR);
          }
          # and keep a list of these files, we will concatenate them later
          push(@{$wkr_outfiles_HA{$info_key}}, $wkr_info_H{$info_key});
        }
        else { # value is not modified for each job
          $wkr_info_H{$info_key} = $info_HR->{$info_key};
        }
      }
      ribo_RunCmsearchOrCmalignOrRRnaSensorOrBlastn($executable, $time_path, $cmfetch_path, $qsub_prefix, $qsub_suffix, $opts, \%wkr_info_H, $opt_HHR, $ofile_info_HHR); 
    }
    
    # wait for the jobs to finish
    ofile_OutputString($log_FH, 0, sprintf("\n"));
    print STDERR "\n";
    ofile_OutputProgressPrior(sprintf("Waiting a maximum of %d minutes for all $nfasta_created $program_choice farm jobs to finish", 
                                      opt_Get("--wait", $opt_HHR)), $progress_w, $log_FH, *STDERR);
    ($njobs_finished, $sum_cpu_plus_wait_secs) = ribo_WaitForFarmJobsToFinish($wkr_outfiles_HA{$wait_key}, $wkr_outfiles_HA{"OUT-NAME:stderr"}, $wait_str, 
                                                                              opt_Get("--wait", $opt_HHR), opt_Get("--errcheck", $opt_HHR), $ofile_info_HHR->{"FH"});
    if($njobs_finished != $nfasta_created) { 
      ofile_FAIL(sprintf("ERROR in $sub_name only $njobs_finished of the $nfasta_created are finished after %d minutes. Increase wait time limit with --wait", 
                         opt_Get("--wait", $opt_HHR)), 1, $ofile_info_HHR->{"FH"});
    }
    ofile_OutputString($log_FH, 1, "# "); # necessary because waitForFarmJobsToFinish() creates lines that summarize wait time and so we need a '#' before 'done' printed by outputProgressComplete()

    # create any output directories we need to create (denoted by special key "OUT-NAME:outdir")
    foreach $info_key (@info_keys_A) { 
      if($info_key eq "OUT-NAME:outdir") { # special case
        my $mkdir_cmd = "mkdir " . $info_HR->{$info_key};
        utl_RunCommand($mkdir_cmd, opt_Get("-v", $opt_HHR), 0, $FH_HR);
      }
    }
 
    # concatenate/merge files into one
    foreach my $outfiles_key (sort keys %wkr_outfiles_HA) { 
      if($outfiles_key eq "OUT-NAME:stk") { # special case
        ribo_MergeAlignmentsAndReorder($execs_HR, $wkr_outfiles_HA{$outfiles_key}, $info_HR->{$outfiles_key}, $info_HR->{"IN:seqlist"}, $opt_HHR, $ofile_info_HHR);
      }
      elsif(($outfiles_key =~ m/^OUT/) && 
            ($outfiles_key ne "OUT-NAME:outdir") && 
            (($outfiles_key ne "OUT-NAME:time") || (defined $time_path)) && 
            ($info_HR->{$outfiles_key} ne "/dev/null")) { 
        # this function will remove files after concatenating them, unless --keep enabled
        utl_ConcatenateListOfFiles($wkr_outfiles_HA{$outfiles_key}, $info_HR->{$outfiles_key}, $sub_name, $opt_HHR, $ofile_info_HHR->{"FH"});
      }
    }

    # remove sequence file partition files, and directories, if nec
    if(! opt_Get("--keep", $opt_HHR)) { 
      # if "OUT-NAME:outdir" is a key, remove those dirs
      if(exists $wkr_outfiles_HA{"OUT-NAME:outdir"}) { 
        ribo_RemoveListOfDirsWithRmrf($wkr_outfiles_HA{"OUT-NAME:outdir"}, $sub_name, $opt_HHR, $ofile_info_HHR->{"FH"});
      }
      if(exists $wkr_outfiles_HA{"IN:seqfile"}) { 
        utl_FileRemoveList($wkr_outfiles_HA{"IN:seqfile"}, $sub_name, $opt_HHR, $ofile_info_HHR->{"FH"});
      }
    }
  } # end of 'else' entered if -p used

  # for both -p and not -p
  # remove the stderr file if it exists and is empty
  if((exists $info_HR->{"OUT-NAME:stderr"}) && 
     (-e $info_HR->{"OUT-NAME:stderr"}) && 
     (! -s $info_HR->{"OUT-NAME:stderr"})) { 
    utl_FileRemoveUsingSystemRm($info_HR->{"OUT-NAME:stderr"}, $sub_name, $opt_HHR, $FH_HR);
  }
  # remove the cmd file if it exists and is empty
  if((exists $info_HR->{"OUT-NAME:cmdscript"}) && 
     (-e $info_HR->{"OUT-NAME:cmdscript"}) && 
     (! -s $info_HR->{"OUT-NAME:cmdscript"})) { 
    utl_FileRemoveUsingSystemRm($info_HR->{"OUT-NAME:cmdscript"}, $sub_name, $opt_HHR, $FH_HR);
  }

  return $sum_cpu_plus_wait_secs; # will be '0' unless -p used
}

#################################################################
# Subroutine:  ribo_MergeAlignmentsAndReorder()
# Incept:      EPN, Tue Jul 10 09:14:49 2018
#
# Purpose:     Given an array of alignment files, merge them into one
#              and reorder all sequences to the order in the file 
#              $seqlist.
#
# Arguments: 
#  $execs_HR:        ref to hash with paths to executables
#  $AR:              ref to array of files to merge
#  $merged_stk_file: path to merged stk file to create
#  $seqlist_file:    file with list of all sequences in the correct order
#  $opt_HHR:         REF to 2D hash of option values, see top of sqp_opts.pm for description
#  $ofile_info_HHR:  REF to 2D hash of output file information
#
# Returns:     void
# 
# Dies: If esl-alimerge fails
################################################################# 
sub ribo_MergeAlignmentsAndReorder { 
  my $sub_name = "ribo_MergeAlignmentsAndReorder";
  my $nargs_expected = 6;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($execs_HR, $AR, $merged_stk_file, $seqlist_file, $opt_HHR, $ofile_info_HHR) = @_;

  my $FH_HR  = $ofile_info_HHR->{"FH"}; # for convenience
  my $log_FH = $ofile_info_HHR->{"FH"}{"log"}; # for convenience

  # create list file 
  my $list_file = $merged_stk_file . ".list";
  utl_AToFile($AR, $list_file, 1, $FH_HR);

  # merge the alignments with esl-alimerge
  utl_RunCommand($execs_HR->{"esl-alimerge"} . " --list $list_file | " . $execs_HR->{"esl-alimanip"} . " --seq-k $seqlist_file --k-reorder --outformat pfam - > $merged_stk_file", opt_Get("-v", $opt_HHR), 0, $FH_HR);

  if(opt_Get("--keep", $opt_HHR)) { 
    ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "$merged_stk_file.list", $merged_stk_file, 0, 1, "list of alignment files merged to create " . ofile_RemoveDirPath($merged_stk_file));
  }
  else { 
    utl_FileRemoveUsingSystemRm($list_file, $sub_name, $opt_HHR, $FH_HR);
  }

  # caller is responsible for adding merged_stk_file to OutputInfo

  return;
}
#################################################################
# Subroutine : ribo_WaitForFarmJobsToFinish()
# Incept:      EPN, Thu Jul  5 14:45:46 2018
#              EPN, Mon Feb 29 16:20:54 2016 [dnaorg_scripts:waitForFarmJobsToFinish()]
#
# Purpose: Wait for jobs on the farm to finish by checking the final
#          line of their output files (in @{$outfile_AR}) to see
#          if the final line is exactly the string
#          $finished_string. We'll wait a maximum of $nmin
#          minutes, then return the number of jobs that have
#          finished. If all jobs finish before $nmin minutes we
#          return at that point.
#
#          A job is considered 'finished in error' if it outputs
#          anything to its err file in @{$errfile_AR}. (We do not kill
#          the job, although for the jobs we are monitoring with this
#          subroutine, it should already have died (though we don't
#          guarantee that in anyway).) If any jobs 'finish in error'
#          this subroutine will continue until all jobs have finished
#          or we've waited $nmin minutes and then it will cause the
#          program to exit in error and output an error message
#          listing the jobs that have 'finished in error'
#          
#          When $do_errcheck is 1, this function considers any output
#          written to stderr output files in @{$errfile_AR} to mean
#          that the corresponding job has 'failed' and should be
#          considered to have finished. When $do_errchecks is 0
#          we don't look at the err files.
# 
#
# Arguments: 
#  $outfile_AR:      ref to array of output files that will be created by jobs we are waiting for
#  $stderrfile_AR:   ref to array of err files that will be created by jobs we are waiting for if 
#                    any stderr output is created
#  $finished_str:    string that indicates a job is finished e.g. "[ok]"
#  $nmin:            number of minutes to wait
#  $do_errcheck:     '1' to consider output to an error file a 'failure' of a job, '0' not to.
#  $FH_HR:           REF to hash of file handles
#
# Returns:     Two values: 
#              $njobs_finished: Number of jobs (<= scalar(@{$outfile_AR})) that have
#                               finished.
#              $sum_cpu_secs:   Summed number of CPU seconds all jobs required, this is an
#                               upper estimate because a job that took 1 second, but that
#                               we didn't check on until 10 seconds elapsed will contribute
#                               10 seconds to this total.
# Dies: never.
#
################################################################# 
sub ribo_WaitForFarmJobsToFinish { 
  my $sub_name = "ribo_WaitForFarmJobsToFinish()";
  my $nargs_expected = 6;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($outfile_AR, $stderrfile_AR, $finished_str, $nmin, $do_errcheck, $FH_HR) = @_;

  my $log_FH = $FH_HR->{"log"};

  my $njobs = scalar(@{$outfile_AR});
  if($njobs != scalar(@{$stderrfile_AR})) { 
    ofile_FAIL(sprintf("ERROR in $sub_name, number of elements in outfile array ($njobs) differ from number of jobs in stderrfile array (%d)", scalar(@{$stderrfile_AR})), 1, $FH_HR);
  }
  my @is_finished_A  = ();  # $is_finished_A[$i] is 1 if job $i is finished (either successfully or having failed), else 0
  my @is_failed_A    = ();  # $is_failed_A[$i] is 1 if job $i has finished and failed (all failed jobs are considered 
                            # to be finished), else 0. We only use this array if the --errcheck option is enabled.
  my $nfinished       = 0;   # number of jobs finished
  my $nfail           = 0;   # number of jobs that have failed
  my $cur_sleep_secs  = 7.5; # number of seconds to wait between checks, we'll double this until we reach $max_sleep, every $doubling_secs seconds
  my $doubling_secs   = 120; # number of seconds to wait before doublign $cur_sleep
  my $max_sleep_secs  = 120; # maximum number of seconds we'll wait between checks
  my $secs_waited     = 0;   # number of total seconds we've waited thus far
  my $sum_cpu_secs    = 0;   # number of CPU seconds required for all jobs summed together
                             # an estimate that is >= actualy number of CPU seconds because
                             # for example, a job that takes 1 second but that we don't check
                             # on for 10 seconds contributes 10 seconds to this total.

  # initialize @is_finished_A to all '0's
  for(my $i = 0; $i < $njobs; $i++) { 
    $is_finished_A[$i] = 0;
    $is_failed_A[$i] = 0;
  }

  my $keep_going = 1;  # set to 0 if all jobs are finished
  ofile_OutputString($log_FH, 0, "\n");
  print STDERR "\n";
  while(($secs_waited < (($nmin * 60) + $cur_sleep_secs)) && # we add $cur_sleep so we check one final time before exiting after time limit is reached
        ($keep_going)) { 
    # check to see if jobs are finished, every $cur_sleep seconds
    sleep($cur_sleep_secs);
    $secs_waited += $cur_sleep_secs;
    if($secs_waited >= $doubling_secs) { 
      $cur_sleep_secs *= 2;
      if($cur_sleep_secs > $max_sleep_secs) { # reset to max if we've exceeded it
        $cur_sleep_secs = $max_sleep_secs;
      }
    }

    for(my $i = 0; $i < $njobs; $i++) { 
      if(! $is_finished_A[$i]) { 
        if(-s $outfile_AR->[$i]) { 
          my $final_line = `tail -n 1 $outfile_AR->[$i]`;
          if(defined $final_line) { 
            chomp $final_line;
            if($final_line =~ m/\r$/) { chop $final_line; } # remove ^M if it exists
            if($final_line =~ m/\Q$finished_str\E/) { 
              $is_finished_A[$i] = 1;
              $nfinished++;
              $sum_cpu_secs += $secs_waited;
            }
          }
          if(($do_errcheck) && (-s $stderrfile_AR->[$i])) { # stderrfile exists and is non-empty, this is a failure, even if we saw $finished_str above
            if(! $is_finished_A[$i]) { 
              $nfinished++;
            }
            $is_finished_A[$i] = 1;
            $is_failed_A[$i] = 1;
            $nfail++;
          }
        }
      }
    }

    # output update
    ofile_OutputString($log_FH, 0, sprintf("#\t%4d of %4d jobs finished (%.1f minutes spent waiting)\n", $nfinished, $njobs, $secs_waited / 60.));
    printf STDERR ("#\t%4d of %4d jobs finished (%.1f minutes spent waiting)\n", $nfinished, $njobs, $secs_waited / 60.);

    if($nfinished == $njobs) { 
      # we're done break out of it
      $keep_going = 0;
    }
  }

  if($nfail > 0) { 
    # construct error message
    my $errmsg = "ERROR in $sub_name, $nfail of $njobs finished in error (output to their respective error files).\n";
    $errmsg .= "Specifically the jobs that were supposed to create the following output and err files:\n";
    for(my $i = 0; $i < $njobs; $i++) { 
      if($is_failed_A[$i]) { 
        $errmsg .= "\t$outfile_AR->[$i]\t$stderrfile_AR->[$i]\n";
      }
    }
    ofile_FAIL($errmsg, 1, $FH_HR);
  }

  # if we get here we have no failures
  return ($nfinished, $sum_cpu_secs);
}

#################################################################
# Subroutine : ribo_ConvertFetchedNameToAccVersion()
# Incept:      EPN, Tue May 29 11:12:58 2018
#
# Purpose:     Given a 'fetched' GenBank sequence name, e.g.
#              gi|675602128|gb|KJ925573.1|, convert it to 
#              just accession version.
#
# Arguments: 
#   $fetched_name: name of sequence
#   $do_die:       '1' to die if the $fetch_name doesn't match the 
#                  expected format
#   $FH_HR:        ref to hash of file handles
#
# Returns: $accver_name: accession version format of the name
#          or $fetched_name if $fetched_name doesn't match 
#          expected format and $do_die is '0'.
# 
# Dies: if $do_die and expected name doesn't match the expected format
#
################################################################# 
sub ribo_ConvertFetchedNameToAccVersion {
  my $sub_name = "ribo_ConvertFetchedNameToAccVersion()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($fetched_name, $do_die, $FH_HR) = (@_);
  
  # example: gi|675602128|gb|KJ925573.1|
  my $accver_name = undef;
  if($fetched_name =~ /^gi\|\d+\|\S+\|(\S+\.\d+)\|.*/) { 
    $accver_name = $1;
  }
  else { 
    if($do_die) { 
      ofile_FAIL("ERROR, in $sub_name, $fetched_name did not match the expected format for a fetched sequence, expect something like: gi|675602128|gb|KJ925573.1|", 1, $FH_HR); 
    }
    $accver_name = $fetched_name;
  }
     
  return $accver_name;
}

#################################################################
# Subroutine: ribo_SumSeqlenGivenArray
# Incept:     EPN, Fri Jul  6 09:30:43 2018
#
# Purpose:    Given an array of sequence names and a hash with 
#             lengths for each, return total length for all 
#             sequences.
#
# Arguments:
#   $seqname_AR:  ref to array of sequence names
#   $seqlen_HR:   ref to hash, key is sequence name, 
#                 value is length
#   $FH_HR:       ref to hash of file handles, including "cmd"
#
# Returns:  void
# 
# Dies:     If sequence listed in @{$seqname_AR} is not in %{$seqlen_HR}
#
#################################################################
sub ribo_SumSeqlenGivenArray { 
  my $sub_name = "ribo_SumSeqlenGivenArray()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqname_AR, $seqlen_HR, $FH_HR) = @_;
  
  my $tot_seqlen = 0;
  foreach my $seqname (@{$seqname_AR}) { 
    if(! exists $seqlen_HR->{$seqname}) { 
      ofile_FAIL("ERROR in $sub_name, $seqname does not exist in the seqlen_H hash", 1, $FH_HR);
    }
    $tot_seqlen += abs($seqlen_HR->{$seqname}); # ribotyper multiplies lengths by -1 after round 1
  }

  return $tot_seqlen;
}

#################################################################
# Subroutine:  ribo_InitializeHashToEmptyString()
# Incept:      EPN, Wed Jun 20 14:29:28 2018
#
# Purpose:     Initialize all values of a hash to the empty string.
#
# Arguments:
#   $HR:  ref to hash to fill with empty string values for all keys in @{$AR}
#   $AR:  ref to array with all keys to create for $HR
#
# Returns:    void
#
# Dies: void
# 
#################################################################
sub ribo_InitializeHashToEmptyString {
  my $sub_name = "ribo_InitializeHashToEmptyString()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($HR, $AR) = (@_);

  %{$HR} = (); 
  foreach my $key (@{$AR}) { 
    $HR->{$key} = "";
  }

  return;
}

#################################################################
# Subroutine:  ribo_InitializeHashToZero()
# Incept:      EPN, Wed Jun 27 12:28:04 2018
#
# Purpose:     Initialize all values of a hash to 0
#
# Arguments:
#   $HR:  ref to hash to fill with empty string values for all keys in @{$AR}
#   $AR:  ref to array with all keys to create for $HR
#
# Returns:    void
#
# Dies: void
# 
#################################################################
sub ribo_InitializeHashToZero { 
  my $sub_name = "ribo_InitializeHashToZero()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($HR, $AR) = (@_);

  %{$HR} = (); 
  foreach my $key (@{$AR}) { 
    $HR->{$key} = 0;
  }

  return;
}

#################################################################
# Subroutine : ribo_NseBreakdown()
# Incept:      EPN, Wed Jan 30 09:50:07 2013 [rfam-family-pipeline:Utils.pm]
#
# Purpose  : Checks if $nse is of format "name/start-end" and if so
#          : breaks it down into $n, $s, $e, $str (see 'Returns' section)
# 
# Arguments: 
#   $seqname:  sequence name, possibly in "name/start-end" format
# 
# Returns:     5 values:
#              '1' if seqname was of "name/start-end" format, else '0'
#              $n:   name ("" if seqname does not match "name/start-end")
#              $s:   start, maybe <= or > than $e (0 if seqname does not match "name/start-end")
#              $e:   end,   maybe <= or > than $s (0 if seqname does not match "name/start-end")
#              $str: strand, "+" if $s <= $e, else "-"
# 
# Dies:        Never
#
################################################################# 
sub ribo_NseBreakdown {
  my $nargs_expected = 1;
  my $sub_name = "ribo_NseBreakdown()";

  my ($sqname) = $_[0];

  my $n;       # sqacc
  my $s;       # start, from seq name (can be > $end)
  my $e;       # end,   from seq name (can be < $start)
  my $str;     # strand, 1 if $start <= $end, else -1

  if($sqname =~ m/^(\S+)\/(\d+)\-(\d+)\s*/) {
    ($n, $s, $e) = ($1,$2,$3);
    $str = ($s <= $e) ? "+" : "-";
    return (1, $n, $s, $e, $str);
  }
  return (0, "", 0, 0, 0); # if we get here, $sqname is not in name/start-end format
}


#################################################################
# Subroutine : ribo_WriteCommandScript()
# Incept:      EPN, Fri Nov  9 14:26:07 2018
#
# Purpose  : Create a new file to be executed as a job created by 
#            a qsub call.
# 
# Arguments: 
#   $file:  name of the file to create
#   $cmd:   the command to put in the file
#   $FH_HR:       ref to hash of file handles, including "cmd"

# Returns:     5 values:
#              '1' if seqname was of "name/start-end" format, else '0'
#              $n:   name ("" if seqname does not match "name/start-end")
#              $s:   start, maybe <= or > than $e (0 if seqname does not match "name/start-end")
#              $e:   end,   maybe <= or > than $s (0 if seqname does not match "name/start-end")
#              $str: strand, "+" if $s <= $e, else "-"
# 
# Dies:        Never
#
################################################################# 
sub ribo_WriteCommandScript {
  my $nargs_expected = 3;
  my $sub_name = "ribo_WriteCommandScript";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($file, $cmd, $FH_HR) = @_;

  open(OUT, ">", $file) || ofile_FileOpenFailure($file, $sub_name, $!, "writing", $FH_HR);

  print OUT ("#!/bin/bash\n");
  print OUT ("#filename: $file\n");
  print OUT $cmd . "\n";

  close(OUT);

  return;
}

#################################################################
# Subroutine : ribo_RemoveListOfDirsWithRmrf()
# Incept:      EPN, Fri Oct 19 12:35:33 2018
#
# Purpose:     Remove each directory in an array of directory
#              names with 'rm -rf'. If there are more than 
#              100 directories, then remove 100 at a time.
# 
# Arguments: 
#   $dirs2remove_AR:    REF to array with list of directories to remove
#   $caller_sub_name:  name of calling subroutine (can be undef)
#   $opt_HHR:          REF to 2D hash of option values, see top of sqp_opts.pm for description
#   $FH_HR:            ref to hash of file handles
# 
# Returns:     Nothing.
# 
# Dies:        If one of the rm -rf commands fails.
#
################################################################# 
sub ribo_RemoveListOfDirsWithRmrf { 
  my $nargs_expected = 4;
  my $sub_name = "ribo_RemoveListOfDirsWithRmrf()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($dirs2remove_AR, $caller_sub_name, $opt_HHR, $FH_HR) = @_;

  my $i = 0; 
  my $ndir = scalar(@{$dirs2remove_AR});

  while($i < $ndir) { 
    my $dir_list = "";
    my $up = $i+100;
    if($up > $ndir) { $up = $ndir; }
    for(my $j = $i; $j < $up; $j++) { 
      $dir_list .= " " . $dirs2remove_AR->[$j];
    }
    my $rm_cmd = "rm -rf $dir_list"; 
    utl_RunCommand($rm_cmd, opt_Get("-v", $opt_HHR), 0, $FH_HR);
    $i = $up;
  }
  
  return;
}

#################################################################
# Subroutine: ribo_WriteAcceptFile
# Incept:     EPN, Wed Jul 11 11:18:31 2018
#
# Purpose:    Given an array of acceptable models, create a ribotyper
#             input --accept file defining those models as acceptable.
#              
# Arguments: 
#   $AR:    reference to array of acceptable models
#   $file:  name of file to create
#   $FH_HR: ref to hash of file handles, including "cmd"
#
# Returns:  Nothing.
# 
# Dies:     If $AR is empty or we can't write to $file.
#
################################################################# 
sub ribo_WriteAcceptFile { 
  my $sub_name = "ribo_WriteAcceptFile()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($AR, $file, $FH_HR) = @_;
  
  my @accept_A = ();

  foreach my $el (@{$AR}) { 
    push (@accept_A, $el . " acceptable\n");
  }

  utl_AToFile(\@accept_A, $file, 1, $FH_HR); # this will die if @accept_A is empty or we can't write to $file
  
  return;
}

#################################################################
# Subroutine: ribo_CheckForTimeExecutable
# Incept:     EPN, Wed Jan  6 08:33:11 2021
#
# Purpose:    Check if $RIBOTIMEDIR/time exists and is executable.
#             If so, return $RIBOTIMEDIR, else return undef.
#              
# Arguments: 
#   NONE
#
# Returns:  $RIBOTIMEDIR environment variable if $RIBOTIMEDIR/time
#           exists and is executable, else undef.
# 
# Dies:     Never.
#
################################################################# 
sub ribo_CheckForTimeExecutable {
  my $sub_name = "ribo_CheckForTimeExecutable()";
  my $nargs_expected = 0;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my $ret_val = undef;
  if(defined $ENV{"RIBOTIMEDIR"}) {
    my $env_ribotime_dir = $ENV{"RIBOTIMEDIR"};
    if(-d $env_ribotime_dir) {
      my $time_exec = $env_ribotime_dir . "/time";
      if((-e $time_exec) || (-x $time_exec)) { 
        $ret_val = $env_ribotime_dir;
      }
      # else $ret_val stays undef
    }
  }

#  if(defined $ret_val) { printf("in $sub_name, returning $ret_val\n"); }
#  else                 { printf("in $sub_name, returning undef\n"); }

  return $ret_val;
}

#################################################################
# Subroutine : ribo_GetDirPath()
# Incept:      EPN, Thu May  4 09:39:06 2017
#              EPN, Mon Mar 15 10:17:11 2010 [ssu.pm:ReturnDirPath()]
#
# Purpose:     Given a file name return the directory path, with the final '/'
#              For example: "foodir/foodir2/foo.stk" becomes "foodir/foodir2/".
#
# Arguments: 
#   $orig_file: name of original file
# 
# Returns:     The string $orig_file with actual file name removed 
#              or "./" if $orig_file is "".
#
################################################################# 
sub ribo_GetDirPath {
  my $narg_expected = 1;
  my $sub_name = "ribo_GetDirPath()";
  if(scalar(@_) != $narg_expected) { printf STDERR ("ERROR, in $sub_name, entered with %d != %d input arguments.\n", scalar(@_), $narg_expected); exit(1); } 
  my $orig_file = $_[0];
  
  $orig_file =~ s/[^\/]+$//; # remove final string of non '/' characters
  
  if($orig_file eq "") { return "./";       }
  else                 { return $orig_file; }
}

#################################################################
# Subroutine : ribo_CreateStoredIndiCmFileName()
# Incept:      EPN, Wed Oct 23 15:36:59 2024
#
# Purpose:     Create a stored indi CM file name string for a CM
#              that will be fetched from a CM library. The format
#              defined here should match with
#              ribo_ParseStoredIndiCmFileName()
#
# Arguments: 
#   $model:    name of model
#   $cmfile:   name of CM library file
# 
# Returns:     string to store for this indi cm file name
#
################################################################# 
sub ribo_CreateStoredIndiCmFileName { 
  my $narg_expected = 2;
  my $sub_name = "ribo_CreateStoredIndiCmFileName()";
  if(scalar(@_) != $narg_expected) { printf STDERR ("ERROR, in $sub_name, entered with %d != %d input arguments.\n", scalar(@_), $narg_expected); exit(1); } 
  my ($model, $cmfile) = (@_);
  
  return "model:$model\nfile:$cmfile";
}

#################################################################
# Subroutine : ribo_ParseStoredIndiCmFileName()
# Incept:      EPN, Wed Oct 23 14:45:41 2024
#
# Purpose:     Parse a stored indi CM file name.
#              If it matches this regex: /^model:[^\n]+\nfile:[^\n]+$/
#              then we will fetch the model from a CM library file and
#              we return the library file name and model name and $do_fetch=1,
#              else it is an individual CM file and we return the file name,
#              undef for the model name and $do_fetch=0
#
# Arguments: 
#   $stored_indi_cmfile: string that is the CM file name, potentially
#                        starting with 'fetch:'.
# 
# Returns:     Two values:
#              $cmfile:   path to the CM file
#              $model:    name of model if $do_fetch is '1' else undef
#              $do_fetch: '1' if we should fetch the CM from the $cmfile,
#                         '0' if $cmfile is a single CM file that we don't
#                         need to fetch from
#
################################################################# 
sub ribo_ParseStoredIndiCmFileName { 
  my $narg_expected = 1;
  my $sub_name = "ribo_ParseStoredIndiCmFileName()";
  if(scalar(@_) != $narg_expected) { printf STDERR ("ERROR, in $sub_name, entered with %d != %d input arguments.\n", scalar(@_), $narg_expected); exit(1); } 
  my $stored_indi_cmfile = $_[0];
  
  my $cmfile = $stored_indi_cmfile;
  my $model  = undef;
  my $do_fetch = 0;

  if($cmfile =~ /^model\:([^\n]+)\nfile\:([^\n]+)$/) { 
    ($model, $cmfile) = ($1, $2);
    $do_fetch = 1;
  }

  return ($cmfile, $model, $do_fetch);
}

#################################################################
# Subroutine: ribo_DupfilterBlastnParams()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Return the blastn parameter string that ribotyper's
#             *DuplicateRegion filter passes to blastn (in addition
#             to -query, -subject and -outfmt). The null threshold
#             table (ribo.dupfilter.null.tsv) is only valid for
#             exactly these parameters, and ribo_DupfilterNullLoad()
#             checks that the table's header records the same string.
#
# Arguments:  none
#
# Returns:    blastn parameter string
#
#################################################################
sub ribo_DupfilterBlastnParams { 
  return "-task blastn -word_size 4 -dust no -soft_masking false -evalue 1000000 -reward 2 -penalty -3 -gapopen 5 -gapextend 2";
}

#################################################################
# Subroutine: ribo_DupfilterBlastnTestedVersions()
# Incept:     Sat Sep 26 2026
#
# Purpose:    Return the blastn versions, as printed by 'blastn
#             -version', that ribotyper's *DuplicateRegion filter
#             has been tested with. The null threshold table was
#             built with the first one; the others gave identical
#             scores. ribotyper refuses to apply the filter with any
#             other version.
#
# Arguments:  none
#
# Returns:    array of version strings, e.g. "2.14.1+"
#
#################################################################
sub ribo_DupfilterBlastnTestedVersions { 
  return ("2.11.0+", "2.14.1+");
}

#################################################################
# Subroutine: ribo_DupfilterBlastnVersion()
# Incept:     Sat Sep 26 2026
#
# Purpose:    Run 'blastn -version' and return the version it
#             reports on its first line ('blastn: <version>').
#
# Arguments:
#   $blastn:  path to the blastn executable
#
# Returns:    version string, e.g. "2.14.1+"
#
# Dies:       if blastn cannot be run, exits non-zero, or its
#             first output line is not 'blastn: <version>'
#
#################################################################
sub ribo_DupfilterBlastnVersion { 
  my $sub_name = "ribo_DupfilterBlastnVersion";
  my $nargs_expected = 1;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($blastn) = (@_);

  my @out_A  = `"$blastn" -version 2>/dev/null`;
  my $status = $?;
  if($status != 0) { 
    die sprintf("ERROR in $sub_name, '$blastn -version' failed (exit status %d)\n", ($status == -1) ? -1 : ($status >> 8));
  }
  my $first = (scalar(@out_A) > 0) ? $out_A[0] : "";
  chomp $first;
  if($first !~ m/^\s*blastn:\s+(\S+)\s*$/) { 
    die "ERROR in $sub_name, could not read a version from the first line of '$blastn -version' output: '$first'\n";
  }

  return $1;
}

#################################################################
# Subroutine: ribo_DupfilterNullMd5()
# Incept:     Sat Sep 26 2026
#
# Purpose:    Return the md5 checksum of the *DuplicateRegion filter
#             null threshold table file (ribo.dupfilter.null.tsv)
#             that this version of Ribovore was released with.
#             ribo_DupfilterNullLoad() refuses to read a table with
#             any other checksum, so that every installation of the
#             same version gives the same results.
#
# Arguments:  none
#
# Returns:    md5 checksum (32 lowercase hex characters)
#
#################################################################
sub ribo_DupfilterNullMd5 { 
  return "e2c834d4f140cc8960bb993337725bd8";
}

#################################################################
# Subroutine: ribo_DupfilterFileMd5()
# Incept:     Sat Sep 26 2026
#
# Purpose:    Return the md5 checksum of a file, computed with the
#             core Perl module Digest::MD5.
#
# Arguments:
#   $file:    path to the file
#
# Returns:    md5 checksum (32 lowercase hex characters)
#
# Dies:       if the file cannot be opened for reading
#
#################################################################
sub ribo_DupfilterFileMd5 { 
  my $sub_name = "ribo_DupfilterFileMd5";
  my $nargs_expected = 1;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($file) = (@_);

  require Digest::MD5;
  my $in_FH = undef;
  open($in_FH, "<", $file) || die "ERROR in $sub_name, unable to open $file for reading\n";
  binmode($in_FH);
  my $md5 = Digest::MD5->new->addfile($in_FH)->hexdigest;
  close($in_FH);

  return $md5;
}

#################################################################
# Subroutine: ribo_DupfilterNullLoad()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Read and validate the *DuplicateRegion filter null
#             threshold table file (ribo.dupfilter.null.tsv). The
#             '#' header must give 'blastn_params', 'len_grid',
#             'at_grid' and 'max_ratio' (as '# <key>: <value>'),
#             and every other non-'#' line is a cell:
#             <lq> <ls> <at_bin> <t05> (tab-separated).
#
#             The file's md5 checksum must equal
#             ribo_DupfilterNullMd5().
#
#             Validation: the header grids parse and are strictly
#             increasing; max_ratio is a positive integer; the
#             header's blastn parameters equal
#             ribo_DupfilterBlastnParams(); every t05 is a number;
#             there are no duplicate cells; and every cell that
#             ribo_DupfilterNullLookupCell() can return exists,
#             with no other cells.
#
# Arguments:
#   $null_file: path to the table file
#
# Returns:    reference to a hash with keys:
#             "len_grid":  ref to array of length grid values
#             "at_grid":   ref to array of AT grid values
#             "max_ratio": maximum ratio of longer to shorter length
#             "t05":       ref to hash, key "<lq>:<ls>:<at_bin>", value t05
#             "header":    ref to hash of all '# <key>: <value>' header values
#             "ncell":     number of cells
#
# Dies:       if the file cannot be read, has the wrong md5 checksum,
#             or fails any validation check. The caller (ribotyper)
#             catches this and exits with an error.
#
#################################################################
sub ribo_DupfilterNullLoad { 
  my $sub_name = "ribo_DupfilterNullLoad";
  my $nargs_expected = 1;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($null_file) = (@_);

  # the table must be exactly the one this version of Ribovore was released with
  my $md5_expected = ribo_DupfilterNullMd5();
  my $md5_found    = ribo_DupfilterFileMd5($null_file);
  if($md5_found ne $md5_expected) { 
    die "ERROR in $sub_name, $null_file is not the table this version of Ribovore was released with (md5 expected $md5_expected, found $md5_found)\n";
  }

  my %header_H = ();
  my %t05_H    = ();
  my $in_FH = undef;
  open($in_FH, "<", $null_file) || die "ERROR in $sub_name, unable to open $null_file for reading\n";
  my $line_ct = 0;
  while(my $line = <$in_FH>) { 
    $line_ct++;
    chomp $line;
    if($line =~ m/^\#/) { 
      if($line =~ m/^\#\s*(\w+)\:\s*(.*\S)\s*$/) { 
        $header_H{$1} = $2;
      }
    }
    elsif($line =~ m/\S/) { 
      my @el_A = split(/\t/, $line);
      if(scalar(@el_A) != 4) { die "ERROR in $sub_name, line $line_ct of $null_file does not have 4 tab-separated fields\n"; }
      my ($lq, $ls, $at, $t05) = (@el_A);
      if(($t05 !~ m/^\-?\d+(\.\d*)?([eE][\+\-]?\d+)?$/) || ($lq !~ m/^\d+$/) || ($ls !~ m/^\d+$/)) { 
        die "ERROR in $sub_name, line $line_ct of $null_file is not <lq> <ls> <at_bin> <t05>\n";
      }
      my $key = $lq . ":" . $ls . ":" . $at;
      if(exists $t05_H{$key}) { die "ERROR in $sub_name, cell $key occurs more than once in $null_file\n"; }
      $t05_H{$key} = $t05 + 0; # store as a number, so e.g. '41.0' is output as '41'
    }
  }
  close($in_FH);

  foreach my $key ("blastn_params", "len_grid", "at_grid", "max_ratio") { 
    if(! defined $header_H{$key}) { die "ERROR in $sub_name, header line '# $key: <value>' missing from $null_file\n"; }
  }
  my %null_H = ("header" => \%header_H, "t05" => \%t05_H, "ncell" => scalar(keys %t05_H));
  foreach my $key ("len_grid", "at_grid") { 
    my @grid_A = split(/\s+/, $header_H{$key});
    for(my $i = 0; $i < scalar(@grid_A); $i++) { 
      if($grid_A[$i] !~ m/^\d+(\.\d+)?$/) { die "ERROR in $sub_name, $key value $grid_A[$i] in $null_file is not a number\n"; }
      if(($i > 0) && ($grid_A[$i] <= $grid_A[($i-1)])) { die "ERROR in $sub_name, $key in $null_file is not strictly increasing\n"; }
    }
    if(scalar(@grid_A) == 0) { die "ERROR in $sub_name, $key in $null_file is empty\n"; }
    $null_H{$key} = \@grid_A;
  }
  if(($header_H{"max_ratio"} !~ m/^\d+$/) || ($header_H{"max_ratio"} < 1)) { die "ERROR in $sub_name, max_ratio in $null_file is not a positive integer\n"; }
  $null_H{"max_ratio"} = $header_H{"max_ratio"};
  ribo_DupfilterAssertBlastnParams(\%null_H, ribo_DupfilterBlastnParams());

  # every cell a lookup can reach must exist, and no other cell may exist
  my $nreachable = 0;
  foreach my $sb (@{$null_H{"len_grid"}}) { 
    my $qmin = ribo_DupfilterRoundUp($sb / $null_H{"max_ratio"}, $null_H{"len_grid"});
    foreach my $qb (@{$null_H{"len_grid"}}) { 
      if(($qb >= $qmin) && ($qb <= $sb)) { 
        foreach my $fb (@{$null_H{"at_grid"}}) { 
          if($fb >= 0.5) { 
            my $key = $qb . ":" . $sb . ":" . $fb;
            if(! exists $t05_H{$key}) { die "ERROR in $sub_name, cell $key is missing from $null_file\n"; }
            $nreachable++;
          }
        }
      }
    }
  }
  if($nreachable != $null_H{"ncell"}) { 
    die sprintf("ERROR in $sub_name, $null_file has %d cells but %d are reachable by lookup\n", $null_H{"ncell"}, $nreachable);
  }

  return \%null_H;
}

#################################################################
# Subroutine: ribo_DupfilterAssertBlastnParams()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Check that a blastn parameter string is the one the
#             null threshold table was built with, ignoring
#             differences in whitespace.
#
# Arguments:
#   $null_HR: ref to null table hash from ribo_DupfilterNullLoad()
#   $live:    blastn parameter string that will be used
#
# Returns:    '1'
#
# Dies:       if the parameter strings differ
#
#################################################################
sub ribo_DupfilterAssertBlastnParams { 
  my $sub_name = "ribo_DupfilterAssertBlastnParams";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($null_HR, $live) = (@_);

  my $table = $null_HR->{"header"}{"blastn_params"};
  my $norm_table = join(" ", split(/\s+/, ($table =~ s/^\s+|\s+$//gr)));
  my $norm_live  = join(" ", split(/\s+/, ($live  =~ s/^\s+|\s+$//gr)));
  if($norm_table ne $norm_live) { 
    die "ERROR in $sub_name, blastn parameters do not match the null table\n  table built with: $table\n  live invocation : $live\n";
  }

  return 1;
}

#################################################################
# Subroutine: ribo_DupfilterOrientPair()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Order two sequences as (blastn query, blastn subject):
#             the shorter one is the query, the orientation the null
#             table was built in. Ties keep the input order.
#
# Arguments:
#   $seqA: first sequence
#   $seqB: second sequence
#
# Returns:    two values: query sequence, subject sequence
#
#################################################################
sub ribo_DupfilterOrientPair { 
  my $sub_name = "ribo_DupfilterOrientPair";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqA, $seqB) = (@_);

  return (length($seqB) < length($seqA)) ? ($seqB, $seqA) : ($seqA, $seqB);
}

#################################################################
# Subroutine: ribo_DupfilterRoundUp()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Return the smallest grid value >= $x (with a 1e-9
#             tolerance), or undef if $x is above the largest.
#
# Arguments:
#   $x:       value to round up
#   $grid_AR: ref to array of grid values, increasing
#
# Returns:    grid value or undef
#
#################################################################
sub ribo_DupfilterRoundUp { 
  my $sub_name = "ribo_DupfilterRoundUp";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($x, $grid_AR) = (@_);

  foreach my $g (@{$grid_AR}) { 
    if($g >= ($x - 1e-9)) { return $g; }
  }

  return undef;
}

#################################################################
# Subroutine: ribo_DupfilterNullLookupCell()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Find the null table cell for two extracts: the shorter
#             and longer lengths and the composition skew
#             max(AT, 1-AT) are each rounded UP to the next grid
#             value, and the shorter length is raised further if
#             needed so that the longer is at most max_ratio times
#             the shorter (lengths below the smallest grid value map
#             to it). Rounding up is conservative: it can only raise
#             the threshold.
#
# Arguments:
#   $null_HR: ref to null table hash from ribo_DupfilterNullLoad()
#   $lenA:    length of first extract
#   $lenB:    length of second extract
#   $at:      AT fraction of the two extracts together
#
# Returns:    cell key "<lq>:<ls>:<at_bin>", or two values (undef,
#             <reason>) if not covered: "LENGTH_ABOVE_GRID" if the
#             longer extract is longer than the largest grid length,
#             "AT_OUT_OF_RANGE" if the skew is above the largest AT
#             grid value
#
#################################################################
sub ribo_DupfilterNullLookupCell { 
  my $sub_name = "ribo_DupfilterNullLookupCell";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($null_HR, $lenA, $lenB, $at) = (@_);

  my ($lq, $ls) = ($lenA <= $lenB) ? ($lenA, $lenB) : ($lenB, $lenA);
  my $sb = ribo_DupfilterRoundUp($ls, $null_HR->{"len_grid"});
  if(! defined $sb) { return (undef, "LENGTH_ABOVE_GRID"); }
  my $qb   = ribo_DupfilterRoundUp($lq, $null_HR->{"len_grid"});
  my $qmin = ribo_DupfilterRoundUp($sb / $null_HR->{"max_ratio"}, $null_HR->{"len_grid"});
  if($qmin > $qb) { $qb = $qmin; }
  my $f  = ($at >= 0.5) ? $at : 1 - $at;
  my $fb = ribo_DupfilterRoundUp($f, $null_HR->{"at_grid"});
  if(! defined $fb) { return (undef, "AT_OUT_OF_RANGE"); }

  return ($qb . ":" . $sb . ":" . $fb);
}

#################################################################
# Subroutine: ribo_DupfilterNullThreshold()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Return the alpha = 0.05 null score threshold for two
#             extracts: a blastn maximum HSP bit score is significant
#             if and only if it is greater than the threshold.
#
# Arguments:
#   $null_HR: ref to null table hash from ribo_DupfilterNullLoad()
#   $lenA:    length of first extract
#   $lenB:    length of second extract
#   $at:      AT fraction of the two extracts together
#
# Returns:    two values: threshold and cell key, or (undef, <reason>)
#             if not covered (see ribo_DupfilterNullLookupCell())
#
# Dies:       if the cell is missing, which ribo_DupfilterNullLoad()
#             rules out
#
#################################################################
sub ribo_DupfilterNullThreshold { 
  my $sub_name = "ribo_DupfilterNullThreshold";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($null_HR, $lenA, $lenB, $at) = (@_);

  my ($key, $why) = ribo_DupfilterNullLookupCell($null_HR, $lenA, $lenB, $at);
  if(! defined $key) { return (undef, $why); }
  if(! exists $null_HR->{"t05"}{$key}) { die "ERROR in $sub_name, internal error, no null table cell $key\n"; }

  return ($null_HR->{"t05"}{$key}, $key);
}

#################################################################
# Subroutine: ribo_DupfilterIsSignificant()
# Incept:     Thu Sep 25 2026
#
# Purpose:    Decide if a blastn maximum HSP bit score for two
#             extracts is significant at alpha = 0.05.
#
# Arguments:
#   $null_HR: ref to null table hash from ribo_DupfilterNullLoad()
#   $bits:    maximum HSP bit score (0 if no HSP)
#   $lenA:    length of first extract
#   $lenB:    length of second extract
#   $at:      AT fraction of the two extracts together
#
# Returns:    two values: '1' or '0' and the cell key, or
#             (undef, <reason>) if not covered
#
#################################################################
sub ribo_DupfilterIsSignificant { 
  my $sub_name = "ribo_DupfilterIsSignificant";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($null_HR, $bits, $lenA, $lenB, $at) = (@_);

  my ($thresh, $key) = ribo_DupfilterNullThreshold($null_HR, $lenA, $lenB, $at);
  if(! defined $thresh) { return (undef, $key); }

  return ((($bits > $thresh) ? 1 : 0), $key);
}

###########################################################################
# the next line is critical, a perl module must return a true value
return 1;
###########################################################################

