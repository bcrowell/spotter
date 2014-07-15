#!/usr/bin/perl -wT

#----------------------------------------------------------------
# Utility functions module for Spotter.
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

#------------------------------------------------------------------------
# To add to the list of units:
#   1. Add a definition to %Spotter::standard_units. Make sure the definition
#      parses to a Measurement, not a bare unit.
#   2. Insert it into %accepts_metric_prefixes, if appropriate.
#------------------------------------------------------------------------
# To add a new unary operator:
#  1. Add to %Spotter::standard_funs_hash.
#  2. If necessary, add to %Spotter::is_nonanalytic.
#------------------------------------------------------------------------
# To add a new binary operator:
#   1. Add it to %Spotter::is_binary_op().
#   2. Add it to the arrays near the top of Parse::parse(). If it has the
#      same precedence as another operator, you can just add it as a pattern-matching
#      option, without lengthening the array.
#   3. Add it to the line in Parse::lex() immediately following this comment:
#          "Exponentiation, or operators that are more than one character:"
#   4. Add appropriate code in Eval::do_binary_op().
#------------------------------------------------------------------------


package Spotter;


use Math::Trig;
use Math::Complex;
use strict vars;
use utf8;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Measurement;

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(@standard_cons @standard_funs
	$roman_chars
	$greek_chars
	$alpha_chars
	$sym_chars
	$legal_chars 
	$symbol_pat 
	%standard_cons_hash 
	@standard_cons
	%standard_funs_hash
	%standard_units
	%standard_prefixes
	%postfix_ops
	@standard_funs
	&array_to_pat
	&is_white
	&is_l_paren
	&is_r_paren
	&is_op
  &is_op_fast
	&is_binary_op
	&is_postfix_op
	&is_null_string
);

%Spotter::standard_cons_hash = (
        # pi supplied by Math::Trig, i by Math::Complex
	"pi"=>Measurement->new(pi),
	"e"=>Measurement->new(exp(1.)),
	"i"=>Measurement->new(i),
        # the numerical values of the following two are arbitrary, unspecified; they don't
        #    need to have their nonstandard_flag set, because that flag is only a property of
        #    results, not variables; the evaluator knows they're special simply because of their names
        "undef"=>Measurement->new(1),
        "inf"=>Measurement->new(1),
);
@Spotter::standard_cons = keys(%Spotter::standard_cons_hash);
%Spotter::standard_funs_hash = (
  "exp"=>\&Math::Complex::exp,
  "ln"=>\&Math::Complex::ln,
  "log"=>\&log10,
  "log10"=>\&log10,
  "sqrt"=>\&Measurement::sqrtm,
  "sin"=>\&Math::Complex::sin,
  "cos"=>\&Math::Complex::cos,
  "tan"=>\&Math::Complex::tan,
  "sec"=>\&Math::Complex::sec,
  "csc"=>\&Math::Complex::csc,
  "cot"=>\&Math::Complex::cot,
  "sinh"=>\&Math::Complex::sinh,
  "cosh"=>\&Math::Complex::cosh,
  "tanh"=>\&Math::Complex::tanh,
  "sech"=>\&Math::Complex::sech,
  "csch"=>\&Math::Complex::csch,
  "coth"=>\&Math::Complex::coth,
  "asin"=>\&Math::Complex::asin,
  "acos"=>\&Math::Complex::acos,
  "atan"=>\&Math::Complex::atan,
  "asinh"=>\&Math::Complex::asinh,
  "acosh"=>\&Math::Complex::acosh,
  "atanh"=>\&Math::Complex::atanh,
  "abs"=>\&Math::Complex::abs,
  "Re"=>\&Math::Complex::Re,
  "Im"=>\&Math::Complex::Im,
  "arg"=>\&Math::Complex::arg,
  "conj"=>\&Crunch::conj,
  "!"=>\&Crunch::factorial,
  "!!"=>\&Crunch::odd_factorial,
  "Gamma"=>\&Crunch::gamma,
  "ln_Gamma"=>\&Crunch::ln_gamma,
  "not"=>\&Eval::do_not,
  "atomize"=>\&Measurement::atomize,
  "units"=>\&Eval::units,
  "base_units"=>\&Eval::base_units,
  );
%Spotter::destroys_units = ("ln"=>1,"log"=>1,"log10"=>1,"arg"=>1);
%Spotter::preserves_units = ("Re"=>1,"Im"=>1,"conj"=>1,"abs"=>1);
%Spotter::changes_units = ("sqrt"=>1,"atomize"=>1,"units"=>1,"base_units"=>1);
	#...functions on the changes_units list should always expect two arguments:
	# a measurement, followed by the units definition hash
%Spotter::is_nonanalytic = ("abs"=>1, "Re"=>1, "Im"=>1, "arg"=>1, "conj"=>1,
			    "not"=>1,);
    # ...see the function of the same name in Expression.pm.
%Spotter::standard_units = (
	"m"=>"",
	"s"=>"",
	"g"=>"",
	"C"=>"",
	"deg"=>"pi/180",
	"N"=>"1000 g.m/s2",
	"J"=>"1000 g.m2/s2",
	"Pa"=>"1000 g/m.s2",
	"W"=>"1000 g.m2/s3",
	"Hz"=>"1 s-1",
	"V"=>"1 J/C",
	"A"=>"1 C/s",
	chr(hex("3a9"))=>"1 V/A",
	"ohm"=>"1 V/A",
	"H"=>"1 J/A2",
	"F"=>"1 C/V",
	"T"=>"1 N.s.C-1.m-1",
	"ft"=>"0.3048 m",
	"in"=>"(1/12) ft",
	"mi"=>"5280 ft",
	"sec"=>"1 s",
	"min"=>"60 s",
	"hr"=>"3600 s",
);
%Spotter::accepts_metric_prefixes = (
    "m"=>1,"s"=>1,"g"=>1,"N"=>1,"J"=>1,"Pa"=>1,"W"=>1,"Hz"=>1,"V"=>1,"A"=>1,
    chr(hex("3a9"))=>1, "ohm"=>1, "H"=>1, "F"=>1, "T"=>1,
);
# parse_prefixed_unit assumes the following are all one character.
%Spotter::standard_prefixes = (
	"f"=>"-15",
	"p"=>"-12",
	"n"=>"-9",
	chr(hex("3bc"))=>"-6", 
	"u"=>"-6", 
	"m"=>"-3",
	"c"=>"-2",
	"k"=>"3",
	"M"=>"6",
	"G"=>"9",
);

%Spotter::postfix_ops = ("!"=>1,"!!"=>1);
@Spotter::standard_funs = keys(%Spotter::standard_funs_hash);

# The following are in one place in order to make it easier to modify them,
# and also to make it easier to check whether non-Unicode-compatible
# stuff has crept in. When modifying them, remember to double all the backslashes.
$Spotter::roman_chars = "a-zA-Z";
$Spotter::greek_chars = "\\x{0391}-\\x{03a9}\\x{03b1}-\\x{03c9}"; 
$Spotter::alpha_chars = "$Spotter::roman_chars$Spotter::greek_chars";
$Spotter::sym_chars   = "$Spotter::alpha_chars\'\_";
$Spotter::legal_chars = "$Spotter::sym_chars\\d\\s\\+\\-\\*\\/\\^\\!\\(\\)\\[\\]\\{\\}\\|\\,\\.\\<\\>\\;\\=\\?"; 
$Spotter::symbol_pat = "[$Spotter::alpha_chars]+[$Spotter::sym_chars\\d]*"; 

sub get_standard_units_hash_ref {
  return \%Spotter::standard_units;
}

sub get_standard_funs_ref {
  return \%Spotter::standard_funs_hash;
}

sub get_standard_cons_ref {
  return \%Spotter::standard_cons_hash;
}

sub foo {
}

sub array_to_pat {
  return join '|',@_;
}

sub is_white {
  return (@_[0] =~ m/^\s+$/);
}

sub is_l_paren {
	return @_[0] eq "(" || @_[0] eq "[" || @_[0] eq "{" || @_[0] eq "|";
}

sub is_r_paren {
	return @_[0] eq ")" || @_[0] eq "]" || @_[0] eq "}" || @_[0] eq "|";
}


sub is_op {
  if (is_binary_op(@_[0])) {return 1;}
  my $r = @_[1];

  # If it's not a binary op, could still be a unary function:

  # old, inefficient:
  #  my $p = array_to_pat(@a);
  #  if (@_[0] =~ m/($p)/) {return 1;}

  # slightly better:
  #my @a = @$r;
  #foreach my $a(@a) {
  #  if (@_[0] eq $a) {return 1}
	#}

  my $u = @_[0];
  if (!($u=~m/^[a-zA-Z!]/) && (length($u)>1 || $u eq '!')) {return 0}
       # ...optimization for speed -- is_op turned out to be a huge CPU hog
  foreach my $a(@$r) {
    if ($u eq $a) {return 1}
	}

  return 0;
}

sub is_op_fast {
  my $u = @_[0];
  if (is_binary_op($u)) {return 1;}
  my $p = @_[1]; # a pattern

  # If it's not a binary op, could still be a unary function:

  if (!($u=~m/^[a-zA-Z!]/) && (length($u)>1 || $u eq '!')) {return 0}
  if ($u =~ m/($p)/) {return 1;}

  return 0;
}

sub is_binary_op {
  return (@_[0] =~ m/^(\,|\+|\-|\*|\/|mod|\^|\*\*|\-\>|__impliedmult|__impliedmultwhitespace|eq|ne|and|or|xor)$/o);
}



sub is_postfix_op {
#  return 1 eq $Spotter::postfix_ops{shift};
   my $x = shift;
   #print "x=$x, result=".exists($Spotter::postfix_ops{$x})."\n";
   return exists($Spotter::postfix_ops{$x});
}


# The following affects the rounding of numbers when we output
# them, and also determines the behavior of the eq operator.
# The 1000 in front may seem overly generous, but e.g. if it's
# only 100, then 10^2^3 eq 10^8 in the test suite fails.
BEGIN {
  my $initialized = 0;
  my $private_tol; # number of decimal digits
  sub get_tol {
    if ($initialized) {return $private_tol;}
    $private_tol = 1000.*10**-&Crunch::float_precision;
    $initialized = 1;
    return $private_tol;
  }
}

sub is_null_string {
  my $x = shift;
  my $r = ref($x);
  return ($r eq "" && $x eq "");
}

1;
