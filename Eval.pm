#!/usr/bin/perl -wT

use Carp::Always; # ubuntu package libcarp-always-perl; otherwise we get warnings from Math::Complex without stack traces
                  # See http://perlmonks.org/?node_id=1023246

#----------------------------------------------------------------
# Expression evaluation module for Spotter.
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

# Evaluates an RPN expression.
#   Mostly this module doesn't do the dirty work on the Measurement objects.
#     That happens through operator overloading. But we do fiddle with the
#     Measurements when we do a function call. Could overload the functions,
#     but that actually makes it harder to add a new function.

package Eval;
use strict vars;
use utf8;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Spotter;
use Measurement;
use Crunch;
use Math::Complex;
use Math::Trig;

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&evaluate &lex_parse_and_eval);

# The following convenience routine evaluates an expression from soup to nuts,
# using only the defaults for everything. There's no error handling other than
# returning a null string. This is meant for evaluating stuff I've defined
# internally, and that I have tested and know will work. Because it doesn't
# have side-effects or depend on anything but defaults, it can be memoized, but
# performance doesn't seem to be improved by memoization.
sub lex_parse_and_eval {
	my $expression = shift;
	my $debug = 0;
	my ($tokens_ref,$errors_ref) =  Parse::lex(EXPRESSION=>$expression);
	my @tt = @$tokens_ref;
	if ($debug) {
	    print "in lex_parse_and_eval\n";
		print "  tokens = ";
		foreach my $token(@tt) {
		  print "'$token' ";
		}
		print "\n";
		if ($errors_ref->[0]) {print "error: " . $errors_ref->[0] . "\n";}
	}
	if ($errors_ref->[0]) {return ""}
	my ($rpn_ref,$errors_ref,$back_refs_ref) = Parse::parse(TOKENS=>$tokens_ref);
	if ($debug) {
		print "  rpn = ";
		foreach my $token(@$rpn_ref) {
		  print "'$token' ";
		}
		print "\n";
		if ($errors_ref->[0]) {print "error: " . $errors_ref->[0] . "\n";}
	}
	if ($errors_ref->[0]) {return ""}
	my ($result,$err_ref) = evaluate(RPN=>$rpn_ref,DEBUG=>0,BACK_REFS=>$back_refs_ref,
						PRETTIFY_UNITS=>0);
					# The PRETTIFY_UNITS=>0 is important -- otherwise we get an infinite
					# loop!
	if ($debug) {
	  print "  result=$result\n";
	}
	return $result;
}

#==================================================================
#==================================================================
#==================================================================
# The evaluator takes an RPN expression and evaluates it numerically.
# The variables, and their Measurement values, are passed as a hash. Same for constants,
# if not using the standard ones.
# Values that aren't Measurements get parsed automatically.
# The result is a Measurement and a ref to a list of errors.
sub evaluate{
  my %args = (
    TOKENS		=> [],
    BACK_REFS	=> {},
    CONSTANTS	=> Spotter::standard_cons_hash,
    FUNCTIONS	=> Spotter::standard_funs_hash,
    VARIABLES	=> {},
    UNITS		=> Spotter::standard_units,
    PRETTIFY_UNITS => 1,
    DEBUG		=> 0,
    @_
  );
  my $rpn_ref = $args{RPN};
  my $cons_ref = $args{CONSTANTS};
  my $funs_ref = $args{FUNCTIONS};
  my $vars_ref = $args{VARIABLES};
  my $units_ref = $args{UNITS};
  my $prettify_units = $args{PRETTIFY_UNITS};
  my $back_refs_ref = $args{BACK_REFS};
  my $debug = $args{DEBUG};
  if ($debug) {print "in evaluate, rpn=@$rpn_ref\n";}
  #print "in evaluate, rpn=@$rpn_ref\n"; # qwe
  my $funs_pat = array_to_pat(keys(%$funs_ref));
  my $cons_pat = array_to_pat(keys(%$cons_ref));
  my $vars_pat = array_to_pat(keys(%$vars_ref));
  my @stack = ();
  my @errors = ();
  my %cons_hash = %$cons_ref;
  my %vars_hash = %$vars_ref;
  my @rpn = @$rpn_ref;
  my %back_refs = %$back_refs_ref;
  #$debug = 1;
  
  if ($debug) {print "in evaluate, cons_hash=@{[%cons_hash]}\n";}
  if ($debug) {print "in evaluate, pats=$funs_pat,$cons_pat,$vars_pat\n";}
  
  for (my $k=0; $k<=$#rpn; $k++) {
    my $token = $rpn[$k];
    my $br = "";
    if (exists($back_refs{$k})) {$br = $back_refs{$k};}
    my $did = 0;
    if ($token =~ m/^units\:(.*)/) { # units
      push @stack,Units::parse_units(TEXT=>$1);
      $did = 1;
    }
    if (is_binary_op($token)) {
      if ($token ne ",") {
        my $b = pop(@stack); # second operand is on top
        my $a = pop(@stack);
        if ((defined $a) && (defined $b)) {
          my $result = do_binary_op($a,$b,$token,$units_ref,$br,\@errors);
          if (! is_null_string($result)) {
            push @stack,$result;
          }
        }
      }
      $did = 1;
    }
    if (!$did && $token =~ m/^($funs_pat)$/) {
      my $x = pop(@stack);
      if (defined $x) {
        my $result = do_fun($x,$token,$units_ref,$br,\@errors);
        if (!is_null_string($result)) {
          push @stack,$result;
        }
      }
      $did = 1;
    }
    if (!$did) {
      my $value = "";
      if (($token =~ m/^($cons_pat)$/ && $cons_pat ne "") || ($token =~ m/^($vars_pat)$/ && $vars_pat ne "")) {
        if ($token =~ m/^($cons_pat)$/ && $cons_pat ne "") {
          if ($debug) {print "in Eval, constant\n"}
          $value = $cons_hash{$token};
        }
        else {
          if ($debug) {print "in Eval, var\n"}
          if (exists $vars_hash{$token}) {
            $value = $vars_hash{$token};
          }
          else {
            $value = &make_undef;
          }
        }
      }
      else { # assume numeric measurement
        if ($debug) {print "in Eval, measurement -$token-\n"}
        $value = $token;
      }
      if ($debug) {print "in Eval, value=$value\n"}
      my $unary_zero = ref($value) eq "" && $value eq "__zero";
      if (ref($value) ne "Measurement" && !is_undef($value) && !$unary_zero) {
        $value = Measurement::parse($value);
      }
      if ($debug) {print "in Eval, measurement=$value\n"}
      push @stack,$value;
      $did = 1;
    }
  }
  if ($debug) {
    foreach my $x (@stack) {
      print "stack: $x\n";
    }
  }
  my $result = pop(@stack);
  if (@stack>0) {push @errors,"e:stack_not_emptied"}
  if (!is_null_string($result) && ref($result) eq "Measurement") {
    #$result=promote_to_measurement($result);
    if ($prettify_units) {
      $result=$result->prettify_units($units_ref);
    }
  }
  return ($result,\@errors);
}

sub do_binary_op {
  my ($a,$b,$op,$units_def_ref,$back_ref,$errors_ref) = @_;
  my $result = "";
  my $bail_out = 0;
  my ($a_raw,$b_raw)=($a,$b);
  my $a_is_units = (ref($a) eq "Units");
  my $b_is_units = (ref($b) eq "Units");
  if ($a_is_units && $b_is_units) {
    if ($op eq "eq") {$result=zero_or_one($a==$b);} # Are they manifestly the same?
    if ($op eq "ne") {$result=zero_or_one($a!=$b);} # Are they manifestly different?
  }
  if (!$a_is_units && $b_is_units) {
    if ($op ne "__impliedmultwhitespace" && $op ne "__impliedmult" && $op ne "/" && $op ne "mod" && $op ne "->") {
	      push @$errors_ref,"e:illegal_op_with_units".$back_ref;
	      $result = "";
	      $bail_out = 1;
    }
  }
  my $unary_sub = (ref($a) eq "" && $a eq "__zero");
  if (!$bail_out && $result eq "") {
          if (!$unary_sub) {
  	    if ($a_is_units) {
  	      $a = Measurement->new(1,$a);
  	    }
  	    else {
  	      $a = promote_to_measurement($a);
  	    }
          }
  	  if ($b_is_units) {
  	    $b = Measurement->new(1,$b);
  	  }
  	  else {
  	    $b = promote_to_measurement($b);
  	  }
	  if ($unary_sub) {# Unary + or -, subvert unit checking.
		  if ($op eq "-") {
			$result = Measurement->new(-$b->number,$b->units);
		  }
		  else { # Otherwise, assume it's unary +.
			$result = Measurement->new($b->number,$b->units);
		  }
	  }
	  else { # not unary sub
		  $a = promote_to_measurement($a);
		  if ($op eq "->") {
		    $result = Measurement::convert($a,$b,$units_def_ref);
		  }
		  if ($op eq "and" || $op eq "or" || $op eq "xor") {
		    if (!$a->reduces_to_unitless($units_def_ref) || !$b->reduces_to_unitless($units_def_ref)) {
			  push @$errors_ref,"e:unit_binary_logical".$back_ref;
			  $result = "";
		    }
		    else {
		      my ($truth_a,$truth_b) = ((0!=$a->number),(0!=$b->number));
		      if ($op eq "and") {$result=($truth_a and $truth_b);}
		      if ($op eq "or")  {$result=($truth_a or $truth_b);}
		      if ($op eq "xor") {$result=($truth_a xor $truth_b);}
                      if ($result eq '') {$result = 0}
		      $result = Measurement->new($result);
		    }
		  }
		  if ($op eq "eq" || $op eq "ne") {
		      # definition of eq: |a-b| <=tol * max(|a|,|b|)
			  my $aa = Measurement::convert($a,$b,$units_def_ref);
			  $aa = $aa->number;
			  my $bb = $b->number;
			  my $diff = abs($aa-$bb); 
			  my ($maga,$magb) = (abs($aa),abs($bb));
			  my $bigger;		
			  if ($maga>$magb) {$bigger=$maga;} else {$bigger=$magb;}
			  my $is_eq = $diff < (&Spotter::get_tol)*($bigger);
			  if ($op eq "ne") {$is_eq = !$is_eq};
			  if ($is_eq) {$result="1";} else {$result="0";}
		  }
		  if ($op eq "+" || $op eq "-") {
		      if (Measurement::compatible_units($a,$b,$units_def_ref)) {
				  my $aa = Measurement::convert($a,$b,$units_def_ref);
				  my $bb = Measurement::convert($b,$a,$units_def_ref);
				  #print "abaabb $a $b $aa $bb\n";
				  my ($result1,$result2);
				  if ($op eq "+") {$result1 = $a+$bb; $result2 = $aa+$b;}
				  if ($op eq "-") {$result1 = $a-$bb; $result2 = $aa-$b;}
				  if ($result1->is_zero || $result2->is_zero) {
					$result = $result1;
				  }
				  else {
				   # Pick whichever version is logarithmically closer to 1.
				   my ($u,$v) = (ln(abs($result1->number)/1.),ln(abs($result2->number)/1.));
				   if (abs($u)<=abs($v)) {
					 $result = $result1;
				   }
				   else {
					 $result = $result2;
				   }
				  }
			  }
			  else {
			  		$result = &make_undef;
			  		my $verb;
			  		if ($op eq "+") {$verb = "add"} else {$verb = "subtract"}
			  		push @$errors_ref,"e:add_incompatible_units".$back_ref.":$verb";
			  }
		  }
		  if ($op eq "*" || $op eq "__impliedmult" || $op eq "__impliedmultwhitespace") {
			$result = $a*$b;
		  }
		  if ($op eq "/") {
			if ($b->is_zero) {
			  push @$errors_ref,"e:div_by_zero".$back_ref;
			  $result = Measurement->new(1,$a->units/$b->units);
			  $result = make_undef($result);
			}
			else {
			  $result = $a/$b;
			}
		  }
		  if ($op eq "mod") {
			if ($b->is_zero) {
			  push @$errors_ref,"e:mod_by_zero".$back_ref;
			  $result = Measurement->new(1,$a->units);
			  $result = make_undef($result);
			}
			else {
			  my $x = promote_to_measurement($a/$b);
			  my $bb = $b;
             if ($x->reduces_to_unitless($units_def_ref)) {
                $x = $x->atomize($units_def_ref); # Takes care of cases like (13 in) mod (1 ft).
                $bb = Measurement::convert($b,$a,$units_def_ref);
              }
			  if (ref($x) eq "Measurement") {$x=$x->number()}
			  $x = Crunch::promote_cplx($x);
			  $x = $bb*promote_to_measurement(Crunch::floor(Re($x)) + Crunch::floor(Im($x))*i);
			  $result = $a - $x;
			}
		  }
		  if ($op eq "**" || $op eq "^") {
			if ($a->is_zero && $b->is_zero) {
			  push @$errors_ref,"e:zero_exp_zero".$back_ref;
			}
			else {
			  $result = Measurement::expon($a,$b,$units_def_ref);
                          if (is_null_string($result)) {push @$errors_ref,"e:expon_err".$back_ref}
			}
		  }
	  } # end if not unary sub
  } # end if not bailing out
  if (is_undef($a_raw) || is_undef($b_raw)) {$result=make_undef($result);}
  return $result;
}

sub do_fun{
  my ($x,$op,$units_ref,$back_ref,$errors_ref) = @_;
  my $f = $Spotter::standard_funs_hash{$op};
  #print "op=$op f=$f\n";
  my $result = "";
  my $did = 0;
  if (exists($Spotter::destroys_units{$op})) {
    my $z;
    if (ref($x) ne "Measurement") {
      $z = promote_cplx($x);
    }
    else {
      my $y;
      if ($x->reduces_to_unitless($units_ref)) {
        $y = $x->atomize($units_ref); # Takes care of cases like exp(1 ft/1 in).
      }
      else {
        $y = $x->number;
      }
      $z = Measurement::number_cplx($y);
    }
    eval{$result = &$f($z);};
    #The following is a workaround for a bug in Math::Complex::ln :
    if ($z==cplx(1.,0.) && $op eq "ln") {$result=0}
    $did = 1;
  }
  if (!$did && exists($Spotter::preserves_units{$op})) {
    eval{$result = &$f(Measurement::number_cplx($x));};
    if (ref($x) eq "Measurement" && !$x->is_manifestly_unitless) {
      $result = Measurement->new($result,$x->units);
    }
    $did = 1;
  }
  if (!$did && exists($Spotter::changes_units{$op})) {
    eval{$result = &$f($x,$units_ref);};
    $did = 1;
  }
  if (!$did) { # Function that requires a unitless argument.
    my $z;
    if (ref($x) ne "Measurement") {
      $z = promote_cplx($x);
    }
    else {
      my $y = $x->atomize($units_ref); # Takes care of cases like exp(1 ft/1 in).
      if (!$y->is_manifestly_unitless) {my $u=$y->units(); push @$errors_ref,"e:function_arg_units".$back_ref.":$op:$u"; return ""}
      $z = Measurement::number_cplx($y);
    }
    eval{$result = &$f($z);};
    $did = 1;
  }
  if (($@ || Spotter::is_null_string($result)) && !is_undef($x)) {
    push @$errors_ref,"e:function_eval".$back_ref.":$op:$x";
    make_undef($result);
    #print "exception: ".$@."\n";
  }
  if (ref($result) eq "Math::Complex") {$result=Crunch::demote_cplx($result)}
  if (ref($result) eq "Measurement") {$result->demote_cplx}
  if (is_undef($x)) {$result=make_undef($result);}
  return $result;
}

sub do_not {
	my $x = shift;
    if ($x==0) {return "1"};
    return "0";
}

sub units {
	my $x = shift;
    if (ref($x) eq "Measurement") {
      return $x->units;
	}
    if (ref($x) eq "Units") {
      return $x;
	}
	return Units->new();
}

sub base_units {
	my $x = shift;
	my $unit_refs = shift;
	my $y = "";
    if (ref($x) eq "Measurement") {
      $y = $x;
	}
    if (ref($x) eq "Units") {
      $y = promote_to_measurement($x);
	}
	if (ref($y) ne "Measurement") {return Units->new();}
	$y = $y->atomize($unit_refs);
	return $y->units;
}

# This sub is duplicated in Crunch.pm.
sub is_undef {
  my $x = shift;
  return (ref($x) eq "" && $x eq "?") || (ref($x) eq "Measurement" && is_undef($x->number));
}

sub make_undef {
  if (!@_) {return Measurement->new("?");}
  my $x = shift;
  #print "refx=".ref($x)."\n";
  if (ref($x) eq "") {return "?";}
  if (ref($x) eq "Units") {return $x;}
  if (ref($x) eq "Measurement") {return Measurement->new("?",$x->units);}
  return "?";
}

sub zero_or_one {
  my $x = shift;
  if ($x) {return "1";} else {return "0";}
}

1;
