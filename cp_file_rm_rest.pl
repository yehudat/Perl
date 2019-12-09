#!/usr/local/bin/perl
#########################################################################################
# Copies a file out of a directory tree and remove all the rest
# The routine uses &finddepth instead of &find. The only difference between the two 
# is when a wanted subroutine is executed. In &find, the "wanted" sub-routine is 
# executed, as soon as an item (dir/file) are encountered, top->bottom, while 
# &finddepth, executed the "wanted" subroutine on the way up, after a sub-tree is 
# scanned, which is bottom->top. In our case, using &find, will fail, as a directory 
# that contains a file will be removed, as it's encountered, without even looking 
# inside, therefore &finddepth MUST be used.
#
# Example:
# Run the script with 2 arguments, first a full path directory to search in and second a
# full path destination directory.
#   perl cp_file_rm_rest.pl $PWD/kuku test.txt $PWD/dest
#########################################################################################
use File::Find;
use File::Copy;

my $required_fname = $ARGV[1];
my $dest_dir       = $ARGV[2];

finddepth(
    sub {
        my $cur_item     = $_;
        $cur_item ne  "." or return;
        $cur_item ne ".." or return;
        #print "CUR_ITEM: ".$cur_item."\n";

        if ($cur_item eq $required_fname) {
            my $src_file_fp  = $cur_item;
            my $dest_file_fp = "$dest_dir\/$cur_item";
            print "move($src_file_fp, $dest_file_fp)\n";
            unless(mkdir $dest_dir) { die "Unable to create $dest_dir\n"; } 
            move($src_file_fp, $dest_file_fp) or die("Cannot copy file $src_file_fp to $dest_file_fp $!");
        } else {
            if (-d $cur_item) {
                print "rmdir($cur_item)\n";
                rmdir($cur_item) or die ("Cannot remove $File::Find::name: $!");
            } else {
                print "unlink($cur_item)\n";
                unlink($cur_item) or die ("Cannot unlink $File::Find::name: $!");
            };
        };
    },
$ARGV[0]);
