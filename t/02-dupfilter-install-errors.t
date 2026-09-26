use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);

# The *DuplicateRegion filter (on by default) must either run exactly as
# released or stop ribotyper with an error: for each installation problem
# below, ribotyper must exit non-zero, before any search, with a message
# that says what is wrong and that --nodupfilter skips the filter; and
# with --nodupfilter it must run normally, with the same output as the
# existing --nodupfilter test.

foreach my $var ("RIBOSCRIPTSDIR", "RIBOINFERNALDIR", "RIBOEASELDIR", "RIBOBLASTDIR") {
  if(! exists $ENV{$var}) { BAIL_OUT("$var env variable not set"); }
}
my $scripts_dir = $ENV{"RIBOSCRIPTSDIR"};
my $blast_dir   = $ENV{"RIBOBLASTDIR"};
my $table       = "models/ribo.dupfilter.null.tsv";
my $fasta       = "$scripts_dir/testfiles/dupfilter-2.fa";
my $exp_short   = "$scripts_dir/testfiles/expected-files/test-nodf2.ribotyper.short.out";

my $tmp_dir = tempdir("ribo-dupfilter-XXXXXX", TMPDIR => 1, CLEANUP => 1);

# make_scripts_dir(): a copy of $RIBOSCRIPTSDIR made of symbolic links,
# except that the null table is absent ($mode "absent") or has one
# threshold changed ($mode "changed")
sub make_scripts_dir {
  my ($mode) = (@_);
  my $dir = "$tmp_dir/scripts-$mode";
  mkdir($dir) || die "unable to make $dir";
  mkdir("$dir/models") || die "unable to make $dir/models";
  foreach my $path (glob("$scripts_dir/*")) {
    my $base = ($path =~ m/([^\/]+)$/)[0];
    if($base ne "models") { symlink($path, "$dir/$base") || die "unable to link $path"; }
  }
  foreach my $path (glob("$scripts_dir/models/*")) {
    my $base = ($path =~ m/([^\/]+)$/)[0];
    if("models/$base" ne $table) { symlink($path, "$dir/models/$base") || die "unable to link $path"; }
  }
  if($mode eq "changed") {
    my ($in_FH, $out_FH);
    open($in_FH,  "<", "$scripts_dir/$table") || die "unable to open $scripts_dir/$table";
    open($out_FH, ">", "$dir/$table")         || die "unable to open $dir/$table";
    my $nchanged = 0;
    while(my $line = <$in_FH>) {
      if(($nchanged == 0) && ($line =~ m/^(\d+\t\d+\t[\d\.]+\t)(\S+)$/)) {
        $line = $1 . ($2 + 1) . "\n";
        $nchanged++;
      }
      print $out_FH $line;
    }
    close($in_FH);
    close($out_FH);
  }
  return $dir;
}

# make_blast_dir(): a directory with a 'blastn' that is not executable
# ($mode "noexec"), reports an untested version ($mode "version"), or
# reports a tested version but fails ($mode "fails") or writes output
# that is not a bit score ($mode "garbage") when run on sequences
sub make_blast_dir {
  my ($mode) = (@_);
  my $dir = "$tmp_dir/blast-$mode";
  mkdir($dir) || die "unable to make $dir";
  my $out_FH;
  open($out_FH, ">", "$dir/blastn") || die "unable to open $dir/blastn";
  if($mode ne "noexec") {
    my $version = ($mode eq "version") ? "2.99.0" : "2.14.1";
    my $run     = ($mode eq "version") ? "exec $blast_dir/blastn \"\$@\"" :
                  ($mode eq "fails")   ? "echo 'BLAST engine error: simulated failure' 1>&2\nexit 3" :
                                         "echo 'not a bit score'\nexit 0";
    print $out_FH "#!/bin/sh\nif [ \"\$1\" = \"-version\" ]; then\n  echo 'blastn: $version+'\n  echo ' Package: blast $version, build Jan  1 2099 00:00:00'\n  exit 0\nfi\n$run\n";
    close($out_FH);
    chmod(0755, "$dir/blastn");
  }
  else {
    print $out_FH "not a blastn executable\n";
    close($out_FH);
    chmod(0644, "$dir/blastn");
  }
  return $dir;
}

my $missing_dir = "$tmp_dir/blast-missing";
mkdir($missing_dir) || die "unable to make $missing_dir";

my @test_AH = (
  { "desc" => "null table absent",           "scripts" => make_scripts_dir("absent"),  "blast" => $blast_dir,
    "errmsg" => qr/null threshold table \S+ribo\.dupfilter\.null\.tsv does not exist/ },
  { "desc" => "null table value changed",    "scripts" => make_scripts_dir("changed"), "blast" => $blast_dir,
    "errmsg" => qr/is not the table this version of Ribovore was released with \(md5 expected [0-9a-f]{32}, found [0-9a-f]{32}\)/ },
  { "desc" => "blastn missing",              "scripts" => $scripts_dir,                "blast" => $missing_dir,
    "errmsg" => qr/blastn executable \S+ does not exist or is not executable/ },
  { "desc" => "blastn not executable",       "scripts" => $scripts_dir,                "blast" => make_blast_dir("noexec"),
    "errmsg" => qr/blastn executable \S+ does not exist or is not executable/ },
  { "desc" => "blastn version not tested",   "scripts" => $scripts_dir,                "blast" => make_blast_dir("version"),
    "errmsg" => qr/is blastn version 2\.99\.0\+, which the filter has not been tested with/ },
  # these two happen during the run, after the searches
  { "desc" => "blastn fails during the run", "scripts" => $scripts_dir,                "blast" => make_blast_dir("fails"), "midrun" => 1,
    "errmsg" => qr/blastn failed \(exit status 3\) comparing two hits of \S+ to \S+: BLAST engine error: simulated failure/ },
  { "desc" => "blastn output unreadable",    "scripts" => $scripts_dir,                "blast" => make_blast_dir("garbage"), "midrun" => 1,
    "errmsg" => qr/could not read blastn output comparing two hits of \S+ to \S+, unexpected line: 'not a bit score'/ },
);

my $orig_dir = getcwd();
chdir($tmp_dir) || die "unable to cd to $tmp_dir";
# run on a copy of the input, so its index file is written here
system("cp $fasta ./") == 0 || die "unable to copy $fasta";
$fasta = "dupfilter-2.fa";
my $i = 0;
foreach my $test_HR (@test_AH) {
  $i++;
  my $env = sprintf("RIBOSCRIPTSDIR=%s RIBOBLASTDIR=%s", $test_HR->{"scripts"}, $test_HR->{"blast"});
  my $out = "df-err$i";
  my $retval = system("$env perl $scripts_dir/ribotyper -f $fasta $out > $out.stdout 2> $out.stderr");
  isnt($retval, 0, $test_HR->{"desc"} . ": exits with an error");
  my $stderr = `cat $out.stderr`;
  like($stderr, $test_HR->{"errmsg"},         $test_HR->{"desc"} . ": error message says what is wrong");
  like($stderr, qr/use the --nodupfilter option/, $test_HR->{"desc"} . ": error message gives --nodupfilter");
  my $log = `cat $out/$out.ribotyper.log`;
  like($log, $test_HR->{"errmsg"}, $test_HR->{"desc"} . ": error message is in the .log file");
  # every command ribotyper runs is listed in its .cmd file
  my $ncmsearch = () = `cat $out/$out.ribotyper.cmd` =~ m/cmsearch/g;
  if(! $test_HR->{"midrun"}) {
    is($ncmsearch, 0, $test_HR->{"desc"} . ": exits before any search");
  }
  else {
    my $nrow = () = `cat $out/$out.ribotyper.short.out` =~ m/^[^#]/mg;
    is($nrow, 0, $test_HR->{"desc"} . ": exits before writing any result to the .short.out file");
  }

  $out = "df-ok$i";
  $retval = system("$env perl $scripts_dir/ribotyper --nodupfilter -f $fasta $out > $out.stdout 2> $out.stderr");
  is($retval, 0, $test_HR->{"desc"} . ": runs with --nodupfilter");
  $ncmsearch = () = `cat $out/$out.ribotyper.cmd` =~ m/cmsearch/g;
  isnt($ncmsearch, 0, $test_HR->{"desc"} . ": --nodupfilter run searches (so the 'before any search' check can fail)");
  my $diff = `diff $out/$out.ribotyper.short.out $exp_short`;
  is($diff, "", $test_HR->{"desc"} . ": --nodupfilter output as expected");
}
chdir($orig_dir);

done_testing();
