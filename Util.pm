use strict;

use Data::Dumper;
use JSON 2.0;

# Returns undef on an error.
sub read_whole_file {
  my $file = shift;
  local $/;
  open(FILE,"<$file") or return undef;
  my $x = <FILE>;
  close FILE;
  return $x;
}

# returns [severity,message] on error, [0,$data] normally
sub read_json_from_file {
  my $file = shift;
  my $hash;
  my $stuff = read_whole_file($file);
  if (! defined $stuff) {return [2,"Error reading file $file"]}
  eval{$hash = JSON::parse_json($stuff)};
  if (!defined $hash) {eval{$hash = JSON::from_json($stuff)}}
  return [2,"JSON syntax error in file $file"] if (! defined $hash) || (!ref $hash);
  return [0,$hash];
}

sub get_config {
  my $par = shift;
  my $x = read_json_from_file("config.json");
  my $err = $x->[0];
  if ($err>0) {return undef}
  return $x->[1]->{$par};
}

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

sub current_date_string_no_time() {
    return sprintf "%04d-%02d-%02d", current_date("year"), current_date("month") ,
    current_date("day");
}

# The following is for debugging: lets me print out complex data structures in the browser.
sub dumpify {
  my $r = shift;
  my $t = Dumper($r);
  # clean up so asciimath won't mung it
  $t =~ s/\_/\\_/g;
  $t =~ s/\$/\\\$/g;
  return $t;
}

sub renice_myself {
  my $incr = shift; # has to be positive
  my $prio = getpriority(0,0);
  my $max = 18; # I think 19 or 20 can cause the process to starve or be terminated
  my $new = $prio+$incr;
  if ($new>$max) {$new=$max}
  if ($new>$prio) {
    POSIX::nice($new-$prio)
  }
}

sub modified {
  my $file = shift;
  my $sb = stat($file);
  return undef if ! defined $sb;
  return $sb->mtime;
}

sub hash_to_js {
  my $filter = shift;
  my %h = @_;
  my @z;
  $filter = '.*' if $filter eq '';
  foreach my $k(keys %h) {if ($k=~/^$filter$/) {my $x=single_quotify($h{$k}); push @z,"'$k':$x"}}
  return '{'.join(',',@z).'}';
}

sub hashref_union_to_hash {
  my $a = shift;
  my $b = shift;
  $a={} if ! ref $a;
  $b={} if ! ref $b;
  return (%$a,%$b);
}

sub append_xml_char_data {
  my $already = shift;
  my $new = shift;
  $already = '' if ! defined $already;
  return $already if $new =~/^\s*$/;
  $new =~ s/^\s*//; # trim leading whitespace
  $new =~ s/[\n\r\t]/ /;
  return $new if $already eq '';
  return "$already $new";
}

sub single_quotify {
  my $s = shift;
  $s  =~ s/'/\\'/g;
  $s  =~ s/\n/ /g;
  return "'$s'";
}

# The following is for consumption by javascript, is needed when paren_debugging_diagram()
# creates ascii-art diagrams to be surrounded by <pre></pre>.
sub single_quotify_with_newlines {
  my $s = shift;
  $s  =~ s/'/\\'/g;
  $s  =~ s/\n/\\n/g;
  return "'$s'";
}

1;
