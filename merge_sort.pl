#!/usr/bin/perl -w
######################################################################
# Merge sort implementation in Perl
######################################################################

use integer;

sub Merge {
    my $array1_p = shift;
    my $array2_p = shift;
    my @array1   = @{ $array1_p };
    my @array2   = @{ $array2_p };
    my @result;

    while ( scalar(@array1)!=0 || scalar(@array2)!=0 ) {
        if ( scalar(@array1)==0 ) {
            push @result, @array2;
            @array2 = (); # empty array
            last;
        };
        if ( scalar(@array2)==0 ) {
            push @result, @array1;
            @array1 = (); # empty array
            last;
        };

        if ($array1[0]>$array2[0]) {
            push @result, $array2[0];
            shift @array2;
        } else {
            push @result, $array1[0];
            shift @array1;
        };
    }
    #print "result=@result\n";
    return \@result;
};

sub DivideAndMerge {
    my $array_p = shift;
    my @array   = @{ $array_p };

    my $offset     = 0;
    my $length     = (scalar @array)/2;

    if ($length>0) {
        my @sub_array1 = splice(@array, $offset, $length);
        my @sub_array2 = @array; # splice removes the "spliced" part

        # Recursive division and merging after the recursion return
        #print "sub_array1=(@sub_array1)\n";
        #print "sub_array2=(@sub_array2)\n";
        my @sort1 = @{&DivideAndMerge(\@sub_array1)};
        my @sort2 = @{&DivideAndMerge(\@sub_array2)};

        return &Merge(\@sort1, \@sort2); # arrays by reference
    };
    return \@array;
};

sub main {
    my @list = (8, 4, 5, 7, 1, 6, 2, 45, 23);
    my @sorted_list;

    print "BEFORE: @list\n";
    @sorted_list = @{ &DivideAndMerge(\@list) };
    print "AFTER : @sorted_list\n";
};

&main();
