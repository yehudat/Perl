#!/usr/bin/perl
################################################################################
# To size a table according to maximum data widths, while printing
################################################################################

use strict; 
use warnings; 
use List::Util qw(min max); 

my @names      = qw(NameA NameB NameC NameD);
my @ages       = (353, 32, 2356, 75);
my @sizes      = (44, 212, 32, 328);
my @scores     = (900, 128, 99, 1000);
my $nameWidth  = max (map length, @names, 'name') + 3;
my $ageWidth   = max (map length, @sizes, 'Age') + 3;
my $sizeWidth  = max (map length, @sizes, 'Size') + 3;
my $scoreWidth = max (map length, @scores, 'Score') + 3; print '-' x ($nameWidth + $ageWidth + $sizeWidth + $scoreWidth), "\n";

printf "%-*s%*s%*s%*s\n", $nameWidth, "Name", $ageWidth, "Age", $sizeWidth, "Size", $scoreWidth, "Score"; 
print '-' x ($nameWidth + $ageWidth + $sizeWidth + $scoreWidth), "\n";

for my $index (0 .. $#names) { 
    printf "%-*s%*s%*s%*s\n", $nameWidth, $names[$index], $ageWidth, $ages[$index], $sizeWidth, $sizes[$index], $scoreWidth, $scores[$index]; 
}
