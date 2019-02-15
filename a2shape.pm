package a2shape;

#
# a2shape.pm:
#
# Compiles input into an AppleSoft BASIC shape table.
# Reference the AppleSoft manual for more info.
#

use strict;

use Exporter::Auto;

sub calc_offset {
  my ($table, $curr_shape, $curr_offset) = @_;

  $table->[2 + ($curr_shape * 2)] = $curr_offset & 0xff;
  $table->[2 + ($curr_shape * 2) + 1] = ($curr_offset >> 8) & 0xff;

  $_[0] = $table;
}

sub check_if_legal {
  my ($byte, $lineno) = @_;

  # Check to see if we're accidentally ignoring bytes
  if ($byte == 0) {
    warn sprintf("Note: All zero byte will be ignored on line %d!\n", $lineno);
  }

  if (($byte & 0xf8) == 0) {
     warn sprintf("Note: Ignoring C and B due to 0 on line %d!\n", $lineno);
  }
}

#
# Input is lines of text with letters for the commands.
#
sub read_input {
  my ($in_file) = @_;

  my $ifh;

  my @lines = ();

  open $ifh, "<$in_file" or die "Can't open $in_file\n";

  while (my $line = readline $ifh) {
    chomp $line;

    # Skip blank lines.
    next if $line =~ /^\s*$/;

    # Skip over comments
    next if $line =~ /^\s*#/;

    push @lines, $line;
  }

  close $ifh;

  return @lines;
}

sub output_table {
  my ($out_file, $output_mode, $num_shapes, $table_size, $table, $dbg, $vbs) = @_;

  my $debug = 0;
  $debug = 1 if defined $dbg && $dbg;

  my $verbose = 0;
  $verbose = 1 if defined $vbs && $vbs;

  my $ofh;

  open $ofh, ">$out_file" or die "Can't write $out_file\n";

  if ($output_mode) {
    print STDERR "Output binary\n" if $debug;
    my @shape_hdr;
    my $offset = 0x6000;

    $shape_hdr[0] = $offset & 0xff;
    $shape_hdr[1] = ($offset >> 8) & 0xff;
    $shape_hdr[2] = $table_size & 0xff;
    $shape_hdr[3] = ($table_size >> 8) & 0xff;

    print STDERR sprintf("Don't forget to POKE 232,%d : POKE 233,%d so Applesoft knows the location of the shape table\n", ($offset & 0xff), (($offset >> 8) & 0xff)) if $verbose;

    foreach my $byte (@shape_hdr) {
      print $ofh chr($byte);
    }

    foreach my $byte (@{$table}) {
      print $ofh chr($byte);
    }
  } else {
    print STDERR "Output Applesoft\n" if $debug;
    # Locate shape table up near HIMEM
    my $address = 0x1ff0 - $table_size;

    print $ofh sprintf("10 HIMEM: %d\n", $address);
    print $ofh sprintf("20 POKE 232,%d : POKE 233,%d\n", ($address & 0xff), ($address >> 8) & 0xff);
    print $ofh sprintf("30 FOR L = %d TO %d: READ B : POKE L,B : NEXT L\n", $address, ($address + $table_size) - 1);
    print $ofh "40 HGR : ROT=0 : SCALE=2\n";
    print $ofh sprintf("50 FOR I = 1 TO %d : XDRAW I AT I*10,100 : NEXT I\n",
      $num_shapes);
    print $ofh "60 END\n";

    for (my $byteno = 0; $byteno < $table_size; $byteno++) {
      if ($byteno % 10 == 0) {
        print $ofh sprintf("%d DATA ", 100 + $byteno / 10);
      }
      print $ofh sprintf("%d", $table->[$byteno]);
      if (($byteno % 10 == 9) || ($byteno == $table_size - 1)) {
        print $ofh "\n";
      } else {
        print $ofh ',';
      }
    }
  }

  close $ofh;
}

sub compile {
  my ($lines, $dbg) = @_;

  my $debug = 0;
  $debug = 1 if defined $dbg && $dbg;

  my @table;

  my $CMD_1 = 0;
  my $CMD_2 = 1;
  my $CMD_3 = 2;

  # Determine the number of shapes from the array size.
  my $num_shapes = scalar @{$lines};
  if ($num_shapes < 1) {
    die "Error getting numshapes\n";
  }
  print STDERR sprintf("Number of shapes = %d\n", $num_shapes) if $debug;

  # First byte of table is low byte of number of shapes.
  $table[0] = ($num_shapes & 0x00ff);
  # Second byte of table is high byte of number of shapes.
  $table[1] = (($num_shapes & 0xff00) >> 8);

  # Skip over number of shapes and the table of offsets.
  my $curr_offset = 2 + (2 * ($num_shapes));

  # Look up table for commands.  Non-plotting are lower case, plotting are upper.
  my %commands = (
    'u' => 0x00,  # Non-plot up.
    'r' => 0x01,  # Non-plot right.
    'd' => 0x02,  # Non-plot down.
    'l' => 0x03,  # Non-plot left.
    'U' => 0x04,  # Plot up.
    'R' => 0x05,  # Plot right.
    'D' => 0x06,  # Plot down.
    'L' => 0x07,  # Plot left.
  );

  for (my $curr_shape = 0; $curr_shape < $num_shapes; $curr_shape++) {
    &calc_offset(\@table, $curr_shape, $curr_offset);

    # Read data.
    my $bits_ptr = $CMD_1;

    my $shape_str = $lines->[$curr_shape];

    # Split the string.
    my @cmds = split //, $shape_str;

    # Look at each command character.
    my $lineno = 0;
    foreach my $cmd (@cmds) {
      $lineno++;
      my $command = '';
      # Use a lookup table to determine command bis based in input.
      if (defined $commands{$cmd}) {
        $command = $commands{$cmd};
      } else {
        print STDERR sprintf("Invalid shape command '%s'", $cmd);
        next;
      }

      # Store the bits into bytes.
      if ($bits_ptr == $CMD_1) {
        # First set of (3) bits
        $table[$curr_offset] = ($command & 0x07);
        # Advance to 2nd set of bits.
        $bits_ptr = $CMD_2;
      } elsif ($bits_ptr == $CMD_2) {
        # Second set of (3) bits
        $table[$curr_offset] |= (($command & 0x07) << 3);
        # Try 3rd set of bits next.
        $bits_ptr = $CMD_3;
      } else {
        # Try to fit in CMD_3.  This can only fit no-plot moves (plot bit not set),
        # also a CMD_3 of 0x00 (no-plot up) is ignored, so it has to go to next byte
        if (($command & 0x04) || ($command == 0x00)) {
          # Store to CMD_1 instead 
          &check_if_legal($table[$curr_offset], $lineno);

          # Go to next byte
          $curr_offset++;
          # Store in first set of bits.
          $table[$curr_offset] = ($command & 0x07);
          # Advance to 2nd set
          $bits_ptr = $CMD_2;
        } else {
          # Store to CMD_3
          $table[$curr_offset] |= (($command & 0x03) << 6);

          &check_if_legal($table[$curr_offset], $lineno);

          # Go to next byte.
          $curr_offset++;
          # First set of bits next.
          $bits_ptr = $CMD_1;
        }
      }
    }

    if ($bits_ptr != $CMD_1) {
      # Move past previous partially filled byte.
      $curr_offset++;
    }

    # Table ends with a 0
    $table[$curr_offset] = 0x00;
    $curr_offset++;
  }

  # Current offset is table size.
  return \@table, $num_shapes, $curr_offset;
}

1;

