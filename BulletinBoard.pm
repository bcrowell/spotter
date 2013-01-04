#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2003 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#----------------------------------------------------------------

package BulletinBoard;

use strict;

sub has_unread_messages {
  my $tree = shift;
  my $username = shift;
  my @keys = unread_message_keys($tree,$username);
  if (@keys) {
    return 1;
  }
  else {
    return 0;
  }
}

sub unread_message_keys {
  my $tree = shift;
  my $username = shift;
  my %result = ();
  if (!($tree->student_inbox_exists($username))) {return keys %result}
  my $inbox = $tree->student_inbox($username);
  open(FILE,"<$inbox") or return keys %result;
  while (my $line = <FILE>) {
    chomp $line;
    my ($action,$date,$key) = split /,/,$line;
    $action =~ s/^\s+//;
    if ($action eq 'sent') {$result{$key} = 1}
    if ($action eq 'received') {delete $result{$key}}
  }
  close FILE;
  return keys %result;
}

sub mark_message_read {
  my $tree = shift;
  my $username = shift;
  my $key = shift;
  my $date = shift;
  my %result = ();
  if (!($tree->student_inbox_exists($username))) {return 'no_inbox'}
  my $inbox = $tree->student_inbox($username);
  open(FILE,">>$inbox") or return 'error_opening_inbox';
  print FILE "received,$date,$key\n";
  close FILE;
  return '';
}

# duplicates code in OpenGrade's DateOG.pm
sub current_date {
    my $what = shift; #=day, mon, year, ...
    my @tm = localtime;
    if ($what eq "day") {return $tm[3]}
    if ($what eq "year") {my $y = $tm[5]; if ($y<1900) {$y=$y+1900} return $y}
    if ($what eq "month") {return ($tm[4])+1}
    if ($what eq "hour") {return $tm[2]}
    if ($what eq "minutes") {return $tm[1]}
    if ($what eq "seconds") {return $tm[0]}
}

# duplicates code in OpenGrade's DateOG.pm
sub current_date_for_message_key() {
    return sprintf "%04d-%02d-%02d-%02d%02d%02d", current_date("year"), current_date("month") ,
    current_date("day"),current_date("hour"),current_date("minutes"),current_date("seconds");
}



sub get_message {
  my $tree = shift;
  my $username = shift; # may matter for subtle reasons having to do with privacy...?
  my $key = shift;
  my $file = $tree->message_filename($key);
  my %headers = ();
  my $body = '';
  open(FILE,$file) or return ['error_opening_file'];
  while (my $line = <FILE>) {
    chomp $line;
    if ($line eq '') {last}
    $line =~ m/([^=]*)=(.*)/;
    $headers{$1} = $2;
  }
  while (my $line = <FILE>) {
    $body = $body . $line;
  }
  close FILE;
  return ['',\%headers,$body];
}


sub html_format_message {
  my $msg = shift;
  my $headers_ref = $msg->[1];
  my $body = $msg->[2];
  my $result = '';
  $body =~ s/\n\s*\n/~~~para~~~/g;
  $body =~ s/\</&lt;/g;
  $body =~ s/\>/&gt;/g;
  my @paragraphs = split /~~~para~~~/,$body;
  $result = $result.'<p><table bgcolor="#eeeeff" width="450"><tr><td>';
  if (exists $headers_ref->{'subject'}) {$result="$result<h3>".($headers_ref->{'subject'})."</h3>\n"}
  foreach my $para(@paragraphs) {
    $result = "$result<p>$para</p>\n";
  }
  $result = $result.'</td></tr></table></p>';
  return $result;
}



return 1;
