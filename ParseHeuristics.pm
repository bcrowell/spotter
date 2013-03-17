#!/usr/bin/perl

#----------------------------------------------------------------
# This module contains some routines that aren't necessary for
# the parser to operate, but that can help to produce better
# error messages. Strings should be sanity-checked before passing
# them to these routines, e.g.:
#       $e = eliminate_illegal_characters($e,' ');
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


package ParseHeuristics;
use strict;
use utf8;

sub errors_found_by_heuristics {
  my $e = shift;
  my $output_mode = shift; # text or html
  my $paren_error = paren_error($e);
  if ($paren_error) {
    my $intro = 'Error: ';
    my $describe = $paren_error; # shouldn't need this, but in case something goes wrong later and we don't recognize the type of error
    if ($paren_error =~ m/^right_without_left:(.*)/) {
      $describe = "A $1 on the right is not matched by any ".partner_paren($1)." on the left.";
    }
    if ($paren_error =~ m/^left_without_right:(.*)/) {
      $describe = "A $1 on the left is not matched by any ".partner_paren($1)." on the right.";
    }
    if ($paren_error =~ m/^mismatched_type:([^:]*):([^:]*)/) {
      $describe = "A $1 on the left is closed by a $2 on the right.";
    }
    if ($output_mode eq 'html') {$describe = $describe . '<br>'}
    $describe = $describe . "\n";
    my $explain_diagram = "The following diagram shows how the parentheses are nested, and may help you to figure out what went wrong.\n"
		."Each parenthesis on the left should have a matching right parenthesis directly across from it on the right.\n";
    my $diagram = paren_debugging_diagram($e);
    #SpotterHTMLUtil::debugging_output("diagram=<pre>$diagram</pre>");
    if ($output_mode eq 'html') {$diagram = '<br/><pre>'.$diagram.'</pre>'} 
    return "$intro$describe\n$explain_diagram\n$diagram";
  }
  return '';
}

sub partner_paren {
  my $c = shift;
  return {'('=>')', ')'=>'(', '['=>']', ']'=>'[', '{'=>'}', '}'=>'{'}->{$c};
}

#---------------------------------------------------------------------------------------
# The following routines are meant to help us give more informative error messages when
# the input contains mismatched parentheses.
#---------------------------------------------------------------------------------------

# returns '' if no error, otherwise an error code describing what's wrong
sub paren_error {
  my $e = shift;
  my @stack = ();
  for (my $i=0; $i<length($e); $i++) {
    my $c = substr($e,$i,1);
    if ($c eq '(' || $c eq '[' || $c eq '{') {
      push @stack,$c;
    }
    if ($c eq ')' || $c eq ']' || $c eq '}') {
      my $left = pop @stack;
      if (! defined $left) {return "right_without_left:$c"}
      my $matching_type = 
           ($left eq '(' && $c eq ')')
        || ($left eq '[' && $c eq ']')
        || ($left eq '{' && $c eq '}');
      if (!$matching_type) {return "mismatched_type:$left:$c"}
    }
  }
  if (@stack) {return 'left_without_right:'.(join '',@stack)}
  return '';
}

sub is_left_paren {
  my $c = shift;
  return ($c eq '(' || $c eq '[' || $c eq '{');
}

sub is_right_paren {
  my $c = shift;
  return ($c eq ')' || $c eq ']' || $c eq '}');
}

sub count_left_parens {
  my $e = shift;
  my $count = 0;
  for (my $i=0; $i<length($e); $i++) {
    ++$count if is_left_paren(substr($e,$i,1));
  }
  return $count;
}

sub count_right_parens {
  my $e = shift;
  my $count = 0;
  for (my $i=0; $i<length($e); $i++) {
    ++$count if is_right_paren(substr($e,$i,1));
  }
  return $count;
}

# returns a 2-dimensional ascii art diagram representing the nesting of the parens
sub paren_debugging_diagram {
  my $e = shift;
  my $nl = count_left_parens($e);
  my $nr = count_right_parens($e);
  $e =~ s/\n//g;
  my @array = ();
  for (my $y=0; $y<($nl+$nr+4); $y++) {
    push @array,(' ' x (length $e));
  }
  my $y = $nr+2; # Could start at y=0, but if the parens don't match, we might then come up above the top.
  for (my $x=0; $x<length($e); $x++) {
    my $c = substr($e,$x,1);
    --$y if is_right_paren($c);
    substr($array[$y],$x,1) = $c;
    #print "y=$y\n";
    ++$y if is_left_paren($c);
  }
  # Remove completely blank lines from the top:
  while ($array[0] =~ m/^ +$/) {
    shift @array;
  }
  # Remove completely blank lines from the bottom:
  while ($array[$#array] =~ m/^ +$/) {
    pop @array;
  }
  # Make the array into a single string:
  my $result = '';
  foreach my $line(@array) {
    $result = "$result$line\n";
  }
  return $result;
}


1;
