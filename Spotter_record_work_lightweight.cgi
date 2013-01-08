#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2007 Benjamin Crowell, GPL v 2 or later
#----------------------------------------------------------------

# This is invoked via XMLHTTPRequest. See java.js. The code looks like this:
# do_get_request('Spotter_record_work_lightweight.cgi?username='+user+'&'+query+'&correct='+1)

use strict;

use FileTree;
use SpotterHTMLUtil;

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



#----------------------------------------------------------------
# Url class
# code duplicated from Spotter.cgi
#----------------------------------------------------------------
package Url;

our %params = ();

# Construct URL that links back to me. The DELETE
# arg tells which params to delete, written like "a"
# to delete a=xxx only, or "(a|b)" to delete more than one.
# If DELETE_ALL is used, then NOT_DELETE is the list
# not to delete, in the same style. Don't use DELETE and
# DELETE_ALL together.
sub link {
  my %args = (
    DELETE_ALL => 0,
    RELATIVE=>1,
    DELETE=>'',
    NOT_DELETE => "(what|debug|file|class)",
    REPLACE => "",
    REPLACE_WITH => "",
    REPLACE2 => "",
    REPLACE_WITH2 => "",
    REPLACE3 => "",
    REPLACE_WITH3 => "",
    @_,
  );
    
  my $cgi = new CGI;
  my $this_script = $cgi->url(-relative=>$args{RELATIVE});
  
  # Workaround for a bug in CGI.pm: If GET and POST are both used, then
  # query_string only gives the javascript form stuff, not the URL stuff.
  #my $q = $cgi->query_string; # doesn't work
  my $q = "";
  my @u = $cgi->url_param;
  foreach my $a(@u) {
    if ($a ne "") {
      $q = $q . $a . "=" . $cgi->url_param($a) . "&"; # Extra & on the end gets cleaned up later
    }
  }

  # --- DELETE
  for (my $i=1; $i<=2; $i++) {
    my $d;
    if ($i==1) {$d = $args{DELETE}}
    if ($d ne "") {
      $q =~ s/$d=[^=\&]*//g;
    }
  }

  # --- DELETE_ALL
  if ($args{DELETE_ALL}) {
    my $nd = $args{NOT_DELETE};
    if ($nd eq "") {
      $q =~ s/[^=\&]+=[^=\&]*//g;
    }
    else {
      my $new = "";
      while ($q =~ m/($nd=[^=\&]*)/g) {
        $new = $new . $1 . "&";
      }
      $q = $new;
    }
  }
  
  # --- REPLACE
  my $r = $args{REPLACE};
  my $rw = $args{REPLACE_WITH};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }
  my $r = $args{REPLACE2};
  my $rw = $args{REPLACE_WITH2};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }
  my $r = $args{REPLACE3};
  my $rw = $args{REPLACE_WITH3};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }
  
  # Tidy up.
  $q =~ s/\&\&+/\&/g; # replace && with &
  $q =~ s/\&+$//g; # strip & off the end
  
  return $this_script."?".$q;
}

sub par_is {
  my ($par,$val) = @_;
  return par($par) && $params{$par} eq $val;
}

sub par_set {
  my ($par) = @_;
  return exists($params{$par});
}

sub par {
  my ($par) = @_;
  return $params{$par};
}

sub report_pars {
  print "<p>Debugging output: list of GET method parameters:<br/>\n";
  foreach my $par(keys(%params)) {
    print "$par=".$params{$par}."<br/>\n";
  }
  print "</p>\n";
}

sub decode_pars {

        my $my_query_string = $ENV{'QUERY_STRING'};
        #my $my_query_string = "file=lm&what=check";
                
        my @query_key_pairs = split(/&/, $my_query_string);
        
        if (! @query_key_pairs) {return 0;}
        
        %params = ();
        foreach my $par (@query_key_pairs) {
          my ($a,$b) = split(/=/, $par);
          my ($aa,$bb,$msg);
          $aa = $a;
          $bb = $b;
          ($aa,$msg) = SpotterHTMLUtil::sanity_check(TEXT=>$a,MAX_LENGTH=>50);
          ($bb,$msg) = SpotterHTMLUtil::sanity_check(TEXT=>$b,MAX_LENGTH=>50);
          $params{$aa} = $bb;
        }
}


