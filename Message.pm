#!/usr/bin/perl -wT

#----------------------------------------------------------------
# Message module for Spotter.
#----------------------------------------------------------------
# Copyright (c) 2001 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#----------------------------------------------------------------

# These routines will eventually have ways of detecting what language
# we want to use.

package Message;

use strict vars;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&print_errors &format_errors);

# Errors should be formatted as follows:
#   severity:code:from:to:highlight_from:highlight_to:...
# where ... indicates additional arguments that apply to this error,
# from:to indicates the tokens of a subexpression that should be displayed,
# and highlight_from:highlight_to is a particular part of that subexpression that
# should be highlighted.
# When to or highlight_to is -1, it means all the way to the end.
# If no subexpression or highlighting is desired, use -2:-2.

sub format_errors {
  my %args = (
    ERRORS_REF	=> [],
    TOKENS_REF	=> [],
    OUTPUT_MODE	=> "text",
    @_
  );
  my $errors_ref = $args{ERRORS_REF};
  my $tokens_ref = $args{TOKENS_REF};
  my $output_mode = $args{OUTPUT_MODE};
  my @errors = @$errors_ref;
  my $result = "";
  foreach my $error (@errors) {
    $result = $result . format_error(ERROR=>$error,TOKENS_REF=>$tokens_ref,OUTPUT_MODE=>$output_mode);
  }
  return $result;
}

sub format_error {
  my %args = (
    ERROR		=> "",
    TOKENS_REF	=> [],
    OUTPUT_MODE	=> "text",
    @_
  );
  my $error = $args{ERROR};
  my $tokens_ref = $args{TOKENS_REF};
  my $output_mode = $args{OUTPUT_MODE};
  my @tokens = @$tokens_ref;
  my @stuff = split /:/,$error;
  my $err_type = format_error_type(shift @stuff);
  my $err_form = get_error_form(shift @stuff);
  my $from = shift @stuff;
  my $to = shift @stuff;
  if ($to == -1) {$to=$#tokens}
  my $highlight_from = shift @stuff;
  my $highlight_to = shift @stuff;
  my $subexpression = "";
  my $hltag = "b"; # html tag for highlighting
  my $do_highlight = ($highlight_from>-2) && ($highlight_to>-2);
  #print "$highlight_from,$highlight_to\n";
  if ($do_highlight) {
    if ($highlight_to== -1) {$highlight_to=$#tokens;}
    $do_highlight = $highlight_to>=$highlight_from
    	            && $highlight_from>=$from && $highlight_to<=$to;
  }
  if ($from>-2 && $to>-2) {
    for (my $i=$from; $i<=$to && $i<=$#tokens && $i>=0; $i++) {
      my $hl_this = ($do_highlight && $output_mode eq "html" 
      			&& $i>=$highlight_from && $i<=$highlight_to);
      #print "hl_this=$hl_this i=$i do_highlight=$do_highlight highlight_from=$highlight_from\n";
      if ($hl_this) {$subexpression=$subexpression."<$hltag>";}
      $subexpression = $subexpression . $tokens[$i];
      if ($hl_this) {$subexpression=$subexpression."</$hltag>";}
    }
    $subexpression =~ s/\<\/$hltag\>\<$hltag\>//g;
  }
  for (my $i=0; $i<=$#stuff; $i++) {
    my $thing = $stuff[$i];
    $err_form =~ s/\~$i/$thing/g;
  }
  my $result = $err_type . $err_form . "\n";
  my $indent = " " x 2;
  if ($subexpression ne "") {
    if ($output_mode eq "html") {$result = $result . "<ul>\n".$indent;}
    $result = $result . $indent . $subexpression;
    # The following code prints "^^^^" under the relevant part of the subexpresssion.
    $result = $result . $indent . "\n";
    if ($do_highlight && $output_mode ne "html") { 
        $result = $result . $indent;
        for (my $i=$from; $i<=$to && $i<=$#tokens && $i<$highlight_from; $i++) {
          $result = $result . (" " x length($tokens[$i]));
        }
        for (my $i=$highlight_from; $i<=$highlight_to && $i<=$#tokens; $i++) {
          $result = $result . ("^" x length($tokens[$i]));
        }
        $result = $result . "\n";
    }
    if ($output_mode eq "html") {$result = $result . "</ul>\n";}
  } # End if subexpression
  return $result;
}

sub format_error_type {
  my $type = shift;
  if ($type eq "e") {return "Error: "}
  if ($type eq "w") {return "Warning: "}
  return "";
}

sub get_error_form {
  my $code = shift;
  if ($code eq "") {return ""}
  
  # lexer
  if ($code eq "undef_sym") {return "undefined variable: ~0"}
  if ($code eq "illegal_chars") {return 'Illegal characters were replaced with "~0".'}
  if ($code eq "illegal_scientific1") {return "~0~1~2~3 was interpreted as (~0)(e)(~3), where e=2.71828... If you intended scientific notation, rewrite this as ~0 10^~3."}
  if ($code eq "illegal_scientific2") {return "~0~1~2~3 was interpreted as (~0)(e)~2~3, where e=2.71828... If you intended scientific notation, rewrite this as ~0 10^~2~3."}

  # ambiguity checker
  if ($code eq "denominator1") {return "Please eliminate the ambiguity by adding parentheses to make either .../~0)(~1... or /(~0~1..."}
  if ($code eq "denominator2") {return "Please eliminate the ambiguity by adding parentheses to make either .../~0)~1(~2... or /(~0~1~2..."}
  if ($code eq "insidefun1") {return "Please eliminate the ambiguity by adding parentheses to make either ...(~0 ~1)~2... or ...~0(~1 ~2)..."}
  if ($code eq "insidefun2") {return "Please eliminate the ambiguity by adding parentheses to make either ...(~0 ~1)~2~3... or ...~0(~1~2~3)..."}

  # parser
  if ($code eq "paren_mismatch") {return "mismatched style of parentheses: ~0...~1"}
  if ($code eq "unbalanced_parens") {return "unbalanced parentheses"}
  if ($code eq "empty_expression") {return "empty expression"}
  if ($code eq "nothing_to_left") {return "There is nothing to the left of the symbol ~0."}
  if ($code eq "nothing_to_right") {return "There is nothing to the right of the symbol ~0."}
  if ($code eq "implied_mult_num_on_right") {return "Don't write implied multiplication with a number on the right, e.g., write 2x, not x2, because x2 could mean x squared. Possible fixes: (a) if you meant multiplication, eliminate the ambiguity by adding parentheses, e.g., (~0)(~1); or (b) if you meant multiplication, rewrite ~0~1 as ~1~0; or (c) if you meant exponentiation, rewrite ~0~1 as ~0^~1."}
  if ($code eq "nothing_inside_parens") {return "nothing inside parentheses"}
  if ($code eq "parse_failed") {return "unable to parse this expression"}
  if ($code eq "fun_without_arg") {return "The function has no argument."}
  if ($code eq "binary_without_args") {return "The operator has nothing to the left or right of it."}

  # evaluator: functions
  if ($code eq "stack_not_emptied") {return "The stack was not empty at the end of the calculation."}

  # evaluator: functions
  if ($code eq "function_arg_units") {return "The function ~0 requires a unitless argument. The argument has units of ~1."}
  if ($code eq "function_eval") {return "error evaluating the function ~0 at ~1"}

  # evaluator: binary operators
  if ($code eq "expon_err") {return "error in exponentiation (Is your exponent unitless?)"}
  if ($code eq "div_by_zero") {return "division by zero"}
  if ($code eq "mod_by_zero") {return "mod by zero"}
  if ($code eq "zero_exp_zero") {return "0^0 is undefined."}
  if ($code eq "illegal_op_with_units") {return "Illegal operation with units. Typically you should write a number, followed by a blank, followed by the units."}
  if ($code eq "unit_binary_logical") {return "The and, or, and xor operators require both operands to be unitless."}
  if ($code eq "add_incompatible_units") {return "You can't ~0 quantities that don't have the same units.".
                                                 " This may indicate an error in your algebra, or a mistake in how you input your expression, e.g.,".
                                                 " entering a+b/c+d when you intended (a+b)/(c+d)."}

  # evaluator: nonstandard values
  if ($code eq "illegal_nonstandard") {return "The only legal expressions that can be constructed from the symbols undef and inf are the following: undef, inf, +inf, and -inf."}
  
  return $code;
}

1;
