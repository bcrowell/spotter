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

package Journal;

use strict;

sub format_journal_as_html {
  my $text = shift;
  my $cooked_text = clean_up_journal_source($text);
  my @paragraphs = ();
  while ($cooked_text =~ m@((\=+[^\n]*\n+)*([^=\n][^\n]*\n)*)@g  ) {
    my $para = $1;
    if (! ($para =~ m/^\s*$/) ) {
      push @paragraphs,$1;
    }
  }
  my $text_width = 450;
  my $annotations_width = 250;
  my $annotations_bg_color = "eeeeee";
  my $td = '<td valign="top" width="'.$text_width.'">';
  my $annotation_td = '<td valign="top" width="'.$annotations_width.'" bgcolor="#'.$annotations_bg_color.'">';
  my $html = "<table>\n";
  foreach my $para(@paragraphs) {
    my $annotations;
    ($para,$annotations) = annotate_journal_paragraph($para);
    $html = $html . "<tr>$td" . format_paragraph_as_html($para) . "</td>\n";
    if ($annotations ne '') {$html = $html . "$annotation_td$annotations</td>"}
    $html = $html . "</tr>\n";
  }
  $html = $html . "</table>\n";
  return $html;
}

sub annotate_journal_paragraph {
  my $para = shift;
  my $annotations = '';
  # Handle annotations like [[foo]]:
  $para =~ s@\[\[(([^/]+/?)*)\]\]@\[\[//$1\]\]@g;
  # Now split out all annotations:
  my $pat = '\[\[(([^/]+/?)*)//(([^\]]+\]?)*)\]\]'; #  [[ $1 // $4 ]]
  while ($para =~ m@$pat@g) {
    $annotations = $annotations . "<b>$1</b> $4<br/>";
  }
  $para =~ s@$pat@<u>$1</u>@g;
  return ($para,$annotations);
}

sub clean_up_journal_source {
  my $text = shift;
  my $cooked_text = $text;
  # Sanitize < and > to avoid trickery:
  $cooked_text =~ s/\</\&lt\;/g;
  $cooked_text =~ s/\>/\&gt\;/g;
  # Make sure it begins with exactly one newline so we can treat 1st line as beginning of a line. At the end, we delete this.
  # Make sure it ends with exactly one newline as well.
  # Also, condense a pair of newlines separated only by whitespace into a simple pair of newlines.
  $cooked_text =~ s/^\s+//;
  $cooked_text = "\n".$cooked_text."\n";
  $cooked_text =~ s/\n\s+\n/\n\n/g;
  $cooked_text =~ s/\n\n\n+/\n\n/g; # Convert 3 or more newlines in a row into one.
  $cooked_text =~ s/^\n\n/\n/; # convert double leading newline to single
  $cooked_text =~ s/\n\n$/\n/; # convert double trailing newline to single
  # Convert tabs to blanks.
  $cooked_text =~ s/\t/ /g;
  # Eliminate whitespace immediately following a newline:
  $cooked_text =~ s/\n +/\n/g;
  # I don't know how the \r characters get in here:
  $cooked_text =~ s/\r\n/\n/g;
  # other characters:
  $cooked_text =~ s/(\260|\272)/deg/g; # octal; 260=degrees, 272 is underlined degrees?
  $cooked_text =~ s/\262/\^2/g; # octal
  $cooked_text =~ s/(\223|\224)/"/g; # octal
  $cooked_text =~ s/\222/'/g; # octal
  return $cooked_text;
}

sub format_paragraph_as_html {
  my $text = shift;
  my $cooked_text = $text;
  # Make sure it has a newline at the beginning:
  if (!($cooked_text =~ m/^\n/)) {$cooked_text = "\n".$cooked_text}
  # Surround paragraphs with <p> tags:
  my $p_tag = '<p class="journal">';
  $cooked_text =~ s@\n(([^\=\*\n][^\n]*\n)+)@\n$p_tag$1</p>\n@g;
  # Convert = to h3, == to h4, etc.:
  my $hstyle = 'class="journal"';
  $cooked_text =~ s@\n===([^\n]*)@\n<h5 $hstyle>$1</h5>@g;
  $cooked_text =~  s@\n==([^\n]*)@\n<h4 $hstyle>$1</h4>@g;
  $cooked_text =~   s@\n=([^\n]*)@\n<h3 $hstyle>$1</h3>@g;
  # Wrap overly long * lines:
  for (my $i=1; $i<=10; $i++) {
    $cooked_text =~ s@\*([^\n]{90})([^\n]+)\n@\*$1\n\*$2\n@g;
  }
  # Handle * lines:
  $cooked_text =~ s@\n\*([^\n]*)@\n<pre>$1</pre>@g;
  # Combine adjacent <pre> tags, etc.:
  $cooked_text =~ s@</pre>\n<pre>@\n@g;
  $cooked_text =~ s@\n\n@\n@g;
  $cooked_text =~ s@\s+</p>@</p>@g;
  $cooked_text =~ s@\s+(</h\d>)@$1@g;
  # Eliminate leading newline:
  $cooked_text =~ s/^\n//;
  return $cooked_text;
}

return 1;
