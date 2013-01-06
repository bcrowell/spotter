#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2007 Benjamin Crowell, GPL v 2 or later
#----------------------------------------------------------------

# This is invoked via XMLHTTPRequest. See java.js. The code looks like this:
# do_get_request('Spotter_record_work_lightweight.cgi?username='+user+'&'+query+'&correct='+1)
# This is only used for multiple-choice questions.

use strict;

use FileTree;
use SpotterHTMLUtil;
use Url;

use utf8;

#$| = 1; # Set output to flush directly (for troubleshooting)

if (!-e 'spotter') {die "the directory 'spotter' doesn't exist within the cgi-bin directory; please create it and make it writeable by the user that apache runs as"}

#----------------------------------------------------------------
# Initialization
#----------------------------------------------------------------
$SpotterHTMLUtil::cgi = new CGI;
Url::decode_pars();

my $tree = FileTree->new(DATA_DIR=>"spotter/",CLASS=>Url::par("class"));
my $user = Url::par("username");
my $file = $tree->student_work_file_name($user);
my $ip = $ENV{REMOTE_ADDR};
my $is_correct = Url::par('correct');
my $query = $ENV{'QUERY_STRING'};
open(FILE,">>$file") or die "error opening work file";
my $nlines = 4;
print FILE "answer,$nlines\n";
print FILE "  query:       $query\n";
print FILE "  correct:     $is_correct\n";
print FILE "  date:        ".current_date_string()."\n";
print FILE "  ip:          $ip\n";
close(FILE);

#----------------------------------------------------------------
#  date stuff
#  duplicated from Spotter.cgi
#----------------------------------------------------------------

# Automatically adds one to month, so Jan=1, and, if year is less than
# 1900, adds 1900 to it. This should ensure that it works in both Perl 5
# and Perl 6.
sub current_date {
    my $what = shift; #=day, mon, year, ...
    my @tm = localtime;
    if ($what eq "sec") {return $tm[0]}
    if ($what eq "min") {return $tm[1]}
    if ($what eq "hour") {return $tm[2]}
    if ($what eq "day") {return $tm[3]}
    if ($what eq "year") {my $y = $tm[5]; if ($y<1900) {$y=$y+1900} return $y}
    if ($what eq "month") {return ($tm[4])+1}
}

sub current_date_string() {
    return sprintf "%04d-%02d-%02d %02d:%02d:%02d", current_date("year"), current_date("month") ,
    current_date("day"),current_date("hour"),current_date("min"),current_date("sec");
}
