#!/usr/local/bin/perl

#----------------------------------------------------------------
#     Expression.pm
#
#     This package is an optional object-oriented interface to
#     Spotter's parser and evaluator. It provides a convenient
#     way to keep all the RPN, error messages, etc. in one place.
#----------------------------------------------------------------


#----------------------------------------------------------------
# Copyright (c) 2001 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#
#----------------------------------------------------------------

package Expression;

use strict;


use Spotter;
use Parse;
use ParseHeuristics;
use Eval;
use Rational;
use Units;
use Measurement;
use Math::Complex;
use Math::Trig;
use Message;
#use XML::Parser;
use utf8;


use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw();

# Normally you specify either VAR_NAMES or VARS, but not both.
#
# Specifying only VAR_NAMES is what you do if you want to parse an expression
# once, and only later plug in values for the variables and evaluate it.
# In this situation, don't supply an empty VARS --- just don't specify it at all.
#
# If you only give the VARS hash, then the VAR_NAMES
# array is then set by using VAR's keys.
#
# If neither is specified, then you are just saying you don't have any variables
# in the expression.
#
# Arguments:
#   EXPR           the expression to parse and evaluate
#   OUTPUT_MODE    "text" or "html"; the format for error messages  
#   VAR_NAMES      ref to an array containing the variable names
#   VARS_REF       ref to hash of Measurements (optional)
#   UNITS_ALLOWED  can the expression contain units, like kg, mV, etc.
sub new {
  my $classname = shift;
  my %args = (
    EXPR=>"",
    OUTPUT_MODE=>"html",
    VAR_NAMES=>[],
    UNITS_ALLOWED=>1,
    @_,
  );
  my $self = {};
  bless($self,$classname);
  
  if (exists($args{VARS})) {
    $self->vars_ref($args{VARS_REF}); # sets VAR_NAMES and HAVE_VARS, too
  }
  else {
    $self->{HAVE_VARS} = 0;
    $self->var_names($args{VAR_NAMES});
  }

  $self->expr($args{EXPR});
  $self->{OUTPUT_MODE} = $args{OUTPUT_MODE};
  $self->{UNITS_ALLOWED} = $args{UNITS_ALLOWED};

  return $self;
}

# return values:
#  -1 parse or lex error
#  0 analytic
#  1 nonanalytic
# This isn't really strictly a test of whether it's analytic everywhere.
# It's more like a test of whether it's got the kind of behavior that would not
# allow us to infer equality of functions everywhere based on equality in
# some local neighborhood.
sub is_nonanalytic {
  my $self = shift;
  $self->lex();  # doesn't actually do anything if already lexed
  if ($self->{HAS_LEX_ERRORS}) {return -1}
  $self->parse();  # doesn't actually do anything if already parsed
  if ($self->{HAS_PARSE_ERRORS}) {return -1;}
  my $rpn = $self->{RPN_REF};
  foreach my $token(@$rpn) {
    if (exists $Spotter::is_nonanalytic{$token}) {
        return 1;
    }
  }
  return 0;
}

# If the optional PARSE_IT arg is set to one, and the expression
# hasn't already been parsed, this routine will try to parse it,
# but won't try to evaulate it if it hasn't already been evaluated.
# You get misleading results if you haven't parsed it, and
# you call this routine without setting PARSE_IT.
# Note to myself: Don't call internally with PARSE_IT=>1, because
# that can result in infinite recursion.
sub has_errors {
  my $self = shift;
  my %args = (
    PARSE_IT => 0,
    @_
  );
  my $parse_it = $args{PARSE_IT};
  if ($self->{HAS_HEUR_ERRORS}) {return 1}
  if ($parse_it) {$self->lex()}  # doesn't actually do anything if already lexed
  if ($self->{HAS_LEX_ERRORS}) {return 1}
  if ($parse_it) {$self->parse();}  # doesn't actually do anything if already parsed
  if ($self->{HAS_PARSE_ERRORS}) {return 1}
  if ($self->{HAS_EVAL_ERRORS}) {return 1}
  return 0;
}

# This lexes and parses if necessary before evaluating.
# The result may or may not be a Measurement object. If you want to make sure
# it's a Measurement object, use Measurement::promote_to_measurement() on it.
sub evaluate {
  #print "in Expression::evaluate, 0<br/>\n";
  my $self = shift;
  $self->parse();
  #print "in Expression::evaluate, 50<br/>\n";
  if ($self->{HAS_LEX_ERRORS} || $self->{HAS_PARSE_ERRORS} || $self->{HAS_EVAL_ERRORS}) {return}
  my $result;
  #print "in Expression::evaluate, 100<br/>\n";
  ($result,$self->{EVAL_ERRORS_REF})
                        = Eval::evaluate(RPN=>$self->{RPN_REF}, VARIABLES=>$self->vars_ref(),
                                                BACK_REFS=>$self->{PARSE_BACK_REFS_REF},PRETTIFY_UNITS=>1,DEBUG=>0);
  #print "in Expression::evaluate, 200<br/>\n";
  if (!null_array_ref($self->{EVAL_ERRORS_REF}) || Eval::is_undef($result)) {
    #print "in Expression::evaluate, has errors, expr=".$self->expr()."result=$result=<br/>\n";
    #print $self->debug_string;
    $self->{HAS_EVAL_ERRORS} = 1;
    return "";
  }
  else {
    #print "in Expression::evaluate, no errors, result=$result=<br/>\n";
    $self->{HAS_EVAL_ERRORS} = 0;
    return $result;
  }
}

sub debug_string {
  my $self = shift;
  my $result = ""; 

  $result = $result . "var_names";
  my $x = $self->var_names;
  my @n = @$x;
  foreach my $n(@n) {
    $result = $result . "=$n=";
  }
  $result = $result ."<br/>\n";

  $result = $result . "vars";
  my $x = $self->vars_ref;
  my %v = %$x;
  foreach my $n(keys(%v)) {
    $result = $result . ",$n=".$v{$n}.",";
  }
  $result = $result ."<br/>\n";

}

sub format_errors {
  my $self = shift;
  my $output_mode = $self->{OUTPUT_MODE};
  # Check heuristics first. When heuristics are available, we presume they'll result in a better error message.
  my $he = ParseHeuristics::errors_found_by_heuristics($self->{EXPR},$output_mode);
  if ($he ne '') {
    $self->{HAS_HEUR_ERRORS} = 1;
    return $he;
  }
  #
  if (!$self->has_errors()) {return ""}
  if ($self->{HAS_LEX_ERRORS}) {
        return Message::format_errors(ERRORS_REF=>$self->{LEX_ERRORS_REF},
                          TOKENS_REF=>$self->{TOKENS_REF},OUTPUT_MODE=>$output_mode);
  }
  if ($self->{HAS_PARSE_ERRORS}) {
        return Message::format_errors(ERRORS_REF=>$self->{PARSE_ERRORS_REF},
                          TOKENS_REF=>$self->{TOKENS_REF},OUTPUT_MODE=>$output_mode);
  }
  if ($self->{HAS_EVAL_ERRORS}) {
        return Message::format_errors(ERRORS_REF=>$self->{EVAL_ERRORS_REF},
                          TOKENS_REF=>$self->{TOKENS_REF},OUTPUT_MODE=>$output_mode);
  }  
  return ""; # shouldn't actually get here, should exit at top
}

sub clear_errors {
  my $self = shift;
  $self->{HAS_LEX_ERRORS} = 0;
  $self->{HAS_PARSE_ERRORS} = 0;
  $self->{HAS_EVAL_ERRORS} = 0;
}



# The following is part of the public interface, but you shouldn't
# normally have to call it directly.
# If the expression has already been lexed, you can call this anyway,
# and it will just return without doing anything.
sub lex {
  my $self = shift;
  if (!$self->have_tokens() && !$self->{HAS_LEX_ERRORS}) {
    my $units_allowed = $self->{UNITS_ALLOWED};
    my $units_ref;
    if ($units_allowed) {
      $units_ref = Spotter::get_standard_units_hash_ref();
    }
    else {
      $units_ref = {};
    }
    ($self->{TOKENS_REF},$self->{LEX_ERRORS_REF}) 
                          = Parse::lex(EXPRESSION=>$self->expr(),VARIABLES=>$self->var_names(),UNITS=>$units_ref,DEBUG=>0);
    if (!null_array_ref($self->{LEX_ERRORS_REF})) {
      $self->{HAS_LEX_ERRORS} = 1;
    }
    else {
      $self->{HAS_LEX_ERRORS} = 0;
      $self->have_tokens(1);
    }
  }
}

sub null_array_ref {
  my $r = shift;
  my @a = @$r;
  if (@a) {return 0} else {return 1}
}

# The following is part of the public interface, but you shouldn't
# normally have to call it directly.
# If the expression has already been parsed, you can call this anyway,
# and it will just return without doing anything.
sub parse {
  my $self = shift;
  if ($self->have_rpn()) {return}
  $self->lex(); # doesn't do anything if already lexed
  if ($self->{HAS_LEX_ERRORS} || !$self->have_tokens()) {return}
  my $aa = $self->var_names();
  my @aa = @$aa;
  my $units_allowed = $self->{UNITS_ALLOWED};
  my $units_ref;
  if ($units_allowed) {
    $units_ref = Spotter::get_standard_units_hash_ref();
  }
  else {
    $units_ref = {};
  }
  ($self->{RPN_REF},$self->{PARSE_ERRORS_REF},$self->{PARSE_BACK_REFS_REF}) =
                  Parse::parse(TOKENS=>$self->{TOKENS_REF},VARIABLES=>$self->var_names(),DEBUG=>0,UNITS=>$units_ref);
  if (!null_array_ref($self->{PARSE_ERRORS_REF})) {
    $self->{HAS_PARSE_ERRORS} = 1;
  }
  else {
    $self->{HAS_PARSE_ERRORS} = 0;
  }
  $self->check_ambiguities();
}

# This is a peepholer that looks at the output of the lexer and uses
# heuristics to detect certain common mistakes, like writing 1/2x
# when you meant 1/(2x).
sub check_ambiguities {
  my $self = shift;
  if (!($self->have_tokens)) {return}
  my $tr = $self->{TOKENS_REF};
  my @tokens = @$tr;
  my $funs_ref = Spotter::get_standard_funs_ref();
  my $funs_pat = array_to_pat(keys(%$funs_ref)); 
  my $cons_ref = Spotter::get_standard_cons_ref();
  my $cons_pat = array_to_pat(keys(%$cons_ref)); 
  my $v = $self->var_names;
  my $vars_pat = array_to_pat(@$v);

  my $sym_pat = "$vars_pat|$cons_pat";
  if ($vars_pat eq '') {$sym_pat = $cons_pat}
  if ($cons_pat eq '') {$sym_pat = $vars_pat}
  if ($cons_pat eq '' && $vars_pat eq '') {$sym_pat = 'nonononooooooooonevermatchme'}

  my @err = ();

  # Look for stuff like 1/2x, which could mean (1/2)x or 1/(2x)
  for (my $i=0; $i<=$#tokens-2; $i++) {
    my ($a,$b,$c) = @tokens[$i..($i+2)];
    if (    $a eq '/'
        && ($b=~m/^($sym_pat)$/ || $b=~m/(\+|\-)?[\d\.]+/)
        && ($c=~m/^($sym_pat)$/ || ($c=~m/^($funs_pat)$/ && $funs_pat ne '') || $c=~m/(\+|\-)?[\d\.]+/ || $c=~m/(\(|\[|\{)/ )  ) {
      my $err = Message::format_error(ERROR=>"w:denominator1:-2:-2:-2:-2:$b:$c",OUTPUT_MODE=>$self->{OUTPUT_MODE});
      push @err,$err;
      $self->{HAS_PARSE_ERRORS} = 1;
      $self->{PARSE_ERRORS_REF} = \@err;
    }
  }

  # Look for stuff like 1/2*x, which could mean (1/2)*x or 1/(2*x)
  for (my $i=0; $i<=$#tokens-3; $i++) {
    my ($a,$b,$c,$d) = @tokens[$i..($i+3)];
    if (    $a eq '/'
        && ($b=~m/^($sym_pat)$/ || $b=~m/(\+|\-)?[\d\.]+/)
        && ($c eq '*' || $c eq ' ')
        && ($d=~m/^($sym_pat)$/ || ($d=~m/^($funs_pat)$/ && $funs_pat ne '') || $d=~m/(\+|\-)?[\d\.]+/ || $d=~m/(\(|\[|\{)/ )  ) {
      my $err = Message::format_error(ERROR=>"w:denominator2:-2:-2:-2:-2:$b:$c:$d",OUTPUT_MODE=>$self->{OUTPUT_MODE});
      push @err,$err;
    }
  }

  # Look for stuff like sin 2x, which could mean sin(2x) or (sin 2)x
  for (my $i=0; $i<=$#tokens-2; $i++) {
    my ($a,$b,$c) = @tokens[$i..($i+2)];
    if (my $err = $self->has_insidefun1_ambiguity($a,$b,$c,$funs_pat,$sym_pat)) {
      push @err,$err;
    }
  }
  for (my $i=0; $i<=$#tokens-3; $i++) {
    my ($a,$b,$c,$d) = @tokens[$i..($i+3)];
    if ((my $err = $self->has_insidefun1_ambiguity($a,$c,$d,$funs_pat,$sym_pat)) && $b eq ' ') {
      push @err,$err;
    }
    if (my $err = $self->has_insidefun2_ambiguity($a,$b,$c,$d,$funs_pat,$sym_pat)) {
      push @err,$err;
    }
  }
  for (my $i=0; $i<=$#tokens-4; $i++) {
    my ($a,$b,$c,$d,$e) = @tokens[$i..($i+4)];
    if ((my $err = $self->has_insidefun2_ambiguity($a,$c,$d,$e,$funs_pat,$sym_pat)) && $b eq ' ') {
      push @err,$err;
    }
  }

  if (@err) {
    $self->{HAS_PARSE_ERRORS} = 1;
    my $e = $self->{PARSE_ERRORS_REF};
    my @e = @$e;
    push @e,@err;
    $self->{PARSE_ERRORS_REF} = \@e;
    #foreach my $err(@err) {print "$err\n"}
  }
}

sub has_insidefun1_ambiguity {
  my $self = shift;
  my ($a,$b,$c,$funs_pat,$sym_pat) = @_;
  if (    $a=~m/^($funs_pat)$/
      && ($b=~m/^($sym_pat)$/ || $b=~m/(\+|\-)?[\d\.]+/)
      && ($c=~m/^($sym_pat)$/ || $c=~m/(\+|\-)?[\d\.]+/ || $c=~m/(\(|\[|\{)/ )  ) {
      return Message::format_error(ERROR=>"w:insidefun1:-2:-2:-2:-2:$a:$b:$c",OUTPUT_MODE=>$self->{OUTPUT_MODE});
  }
}

sub has_insidefun2_ambiguity {
  my $self = shift;
  my ($a,$b,$c,$d,$funs_pat,$sym_pat) = @_;
  if (    $a=~m/^($funs_pat)$/
      && ($b=~m/^($sym_pat)$/ || $b=~m/(\+|\-)?[\d\.]+/)
      && ($c eq '*' || $c eq '/' || $c eq ' ')
      && ($d=~m/^($sym_pat)$/ || $d=~m/(\+|\-)?[\d\.]+/ || $d=~m/(\(|\[|\{)/ )  ) {
      return Message::format_error(ERROR=>"w:insidefun2:-2:-2:-2:-2:$a:$b:$c:$d",OUTPUT_MODE=>$self->{OUTPUT_MODE});
  }
}

sub have_tokens {
  my $self = shift;
  if (@_) {$self->{HAVE_TOKENS} = shift;}
  return $self->{HAVE_TOKENS};
}

sub have_rpn {
  my $self = shift;
  if (@_) {$self->{HAVE_RPN} = shift;}
  return $self->{HAVE_RPN};
}

sub have_vars {
  my $self = shift;
  if (@_) {$self->{HAVE_VARS} = shift;}
  return $self->{HAVE_VARS};
}

sub vars_ref {
  my $self = shift;
  if (@_) {
    my $x = shift;
    $self->{VARS_REF} = $x;
    $self->{HAVE_VARS} = 1;
    $self->clear_result();
    my %h = %$x;
    my @k = keys(%h);
    $self->var_names(\@k);
  }
  return $self->{VARS_REF};
}


sub var_names {
  my $self = shift;
  if (@_) {$self->{VAR_NAMES} = shift;}
  return $self->{VAR_NAMES};
}

sub expr {
  my $self = shift;
  if (@_) {
    $self->{EXPR} = shift;
    $self->clear();
  }
  return $self->{EXPR};
}

sub clear_result {
  my $self = shift;
  $self->{HAS_EVAL_ERRORS} = 0;
}

sub clear {
  my $self = shift;
  $self->clear_errors();
  $self->have_tokens(0);
  $self->have_rpn(0);
  $self->clear_result();
}

1;

