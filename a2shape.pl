#!/usr/bin/perl -w

#
# a2shape.pl
#
# Compiles input into an AppleSoft BASIC shape table.
# Reference the AppleSoft manual for more info.
#

use strict;

use a2shape;

my $debug = 0;
my $verbose = 0;
my $output_mode = 1;

sub usage {
  print "Usage:\t$0 [-h] [-a] [-b] [-d] in_file out_file\n\n";
  print "\t-h\tPrint this usage\n";
  print "\t-a\tOutput shape table in Applesoft BASIC format\n";
  print "\t-b\tOutput shape table in binary format for BLOADing\n";
  print "\t-v\tTurn on verbose\n";
  print "\t-d\tTurn on debug\n";
  print "\n";
  exit 1;
}

sub process {
  my ($in_file, $out_file, $output_mode) = @_;

  # Read the input.
  my @lines = &read_input($in_file);

  # Compile the shape table.
  my ($table, $num_shapes, $table_size) = &compile(\@lines, $debug);

  print STDERR sprintf("Shape table size %d\n", $table_size) if $debug;

  # Output the shape table.
  &output_table($out_file, $output_mode, $num_shapes, $table_size, $table, $debug, $verbose);
}

# Process command line arguments.
while (defined $ARGV[0] && $ARGV[0] =~ /^-/) {
  if ($ARGV[0] eq '-h') {
    &usage();
  } elsif ($ARGV[0] eq '-b') {
    $output_mode = 1;
    shift;
  } elsif ($ARGV[0] eq '-a') {
    $output_mode = 0;
    shift;
  } elsif ($ARGV[0] eq '-v') {
    $verbose = 1;
    shift;
  } elsif ($ARGV[0] eq '-d') {
    $debug = 1;
    shift;
  } else {
    print "Unrecognized flag $ARGV[0]\n";
    &usage();
  }
}

my $in_file = shift or die "Must supply input filename\n";;
my $out_file = shift or die "Must supply output filename\n";;

&process($in_file, $out_file, $output_mode, $debug, $verbose);

1;

