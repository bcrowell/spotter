#!/usr/bin/perl -wT

#----------------------------------------------------------------
# Number-crunching module for Spotter.
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

package Crunch;

use strict vars;
use Math::Complex;
use Math::Trig;
use Spotter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&factorial &odd_factorial &demote_cplx &promote_cplx &gamma
			&nearest_int &is_real &is_int);

sub factorial{
  my $x = promote_cplx(shift);
  my $y = gamma($x+1);
  if (Spotter::is_null_string($y)) {return ""}
  if (is_int($x) && Re($x)>=0) {return nearest_int($y)}
  return $y;
}

sub odd_factorial{
  my $x = shift;
  my $k = ($x-1.)/2.;
  my $f1 = factorial($x);
  my $f2 = factorial($k);
  if (Spotter::is_null_string($f1)) {return ""}
  if (Spotter::is_null_string($f2)) {return ""}
  return $f1/$f2/2.**$k;
}

sub demote_cplx {
 my $x = shift; 
 unless (ref($x)) {return $x} # for efficiency
 $x = promote_cplx($x);
  if (Im($x)==0) {
    $x = Re($x);
  }
  return $x;
}


sub promote_cplx{
  my $x = shift;
  # Math::Complex prints warnings which are not exceptions. See http://perlmonks.org/?node_id=1023246
  # Because they're not exceptions, the eval below doesn't really help, and we need the check against is_undef().
  return 0+0*i if is_undef($x);
  eval{$x = $x + 0*i;};
  if ($@) {$x = 0+0*i}
  return $x;
}

# This sub is duplicated in Eval.pm.
sub is_undef {
  my $x = shift;
  return (ref($x) eq "" && $x eq "?") || (ref($x) eq "Measurement" && is_undef($x->number));
}

sub conj {
  my $x = promote_cplx(shift);
  return cplx(Re($x),-Im($x));
}

sub gamma {
  my $x = promote_cplx(shift);
  my $g = ln_gamma($x);
  if (Spotter::is_null_string($g)) {return ""}
  my $y = exp($g);
  if (is_real($x)) {return Re($y)}
  return $y;
}

sub floor {
  my $x = shift;
  my $y = int($x);
  while ($y+1<$x) {$y++}
  while ($y>$x) {$y--}
  return $y;
}
# Testing: Tested against all the examples given in the Borland page.
# Tested for positive and negative integers.
# Checked that the reflection rule worked for imaginary z, by
# comparing with the result of the plus-one rule.
sub ln_gamma {
  my $z = promote_cplx(shift);
  if (is_int($z) && Re($z)<=0) {return ""}
  if (Im($z)<0.) {return conj(ln_gamma(conj($z)));}
  if (Re($z)<0.) {
    return ln(pi)-ln(sin(pi*$z))-ln_gamma(1.-$z); #reflection rule
  }
  # Note that the following recursion is never more than 9 or 10 deep,
  # since we've already checked that Re(z) is at least one.
  if (Re($z)<9.) {
    return ln_gamma($z+1.)-ln($z); #plus-one rule
  }
  return ln_gamma_series($z);
}

# The following is only a good approximation for the part of the complex
# plane with x>=9 and y>=0.
# Got the equation from http://homepages.borland.com/efg2lab/Mathematics/Complex/Gamma.htm.
# They got it from Table of the Gamma Function for Complex Arguments, U.S. National
# Bureau of Standards Applied Mathematics Series No. 34, Aug 1954, p. VII.
sub ln_gamma_series {
  my $z = shift; # has to be Complex
  return ($z-.5)*ln($z)-$z+.5*ln(2.*pi)
  	+ evaluate_polynomial(1./$z,
  			0.,
  			1./12.,
  			0.,
  			-1./360.,
  			0.,
  			1./1260.,
  			0.,
  			-1./1680.,
  			0.,
  			1./1188.,
  			0.,
  			-691./360360.,
  			0.,
  			1./156.,
  			0.,
  			-3617./122400.);
}

# First arg is complex number x. [1]=x^0 term, etc.
sub evaluate_polynomial {
  my $x = shift;
  my @c = @_;
  my $p = 1.;
  my $result = 0.;
  for (my $i=0; $i<=$#c; $i++) {
    $result = $result + $c[$i]*$p;
    $p = $p * $x;
  }
  return $result;
}

sub nearest_int {
  my $x = shift;
  if (!is_real($x)) {return "";}
  my $y = int($x);
  if (abs($x-($y+1))<abs($x-$y)) {$y=$y+1}
  if (abs($x-($y-1))<abs($x-$y)) {$y=$y-1}
  return $y
}

sub is_int {
  my $x = shift;
  return is_real($x) && $x==nearest_int($x);
}

sub is_real {
  return Im(promote_cplx(shift))==0;
}

sub prettify_floating_point {
  my $n = shift;
  my $debug = 0;
  # Convert notation like 1e+10 to something that we'd actually
  # accept as input:
  $n =~ s/(\-?[\d\.]+)e([\+\-]?)0(\d+)/$1\*10\^$2$3/; # leading zero
  if ($debug) {print "1 $n\n";}
  $n =~ s/(\-?[\d\.]+)e([\+\-]?\d+)/$1\*10\^$2/; # no leading zero
  if ($debug) {print "2 $n\n";}
  $n =~ s/(\-?[\d\.]+)\*10\^+(\d+)/$1\*10\^$2/; # Eliminate + in exponent.
  if ($debug) {print "3 $n\n";}
  
  # Round off stuff like 1.0000000001, 0.99999999999.
  
  $n =~ m/\s*(\-?)([\d\.]+)(.*)\s*/;
  my $sn = $1;
  my $leading_part = $2;
  my $trailing_part = $3;
  my $exp = 0;
  if ($trailing_part ne "") {
    $trailing_part =~ m/\*10\^([\+\-]?[\d]+)/;
    $exp = $1;
  }
  
  if ($debug) {print "4 $sn $leading_part $trailing_part $exp\n";}
  
  if ($leading_part==0) {return "0";}
  
  # In the following, note that leading part is guaranteed to be >0.
  my $z = nearest_int(log10($leading_part));
  $leading_part = $leading_part * 10**(-$z);
  $exp = $exp + $z;
  # Here, try to round up stuff like 0.999999 to 1, so that it can get recognized
  # as an integer later.
  if ($leading_part<0.9) {$leading_part=$leading_part*10; $exp=$exp-1;}
  if ($leading_part>=10.) {$leading_part=$leading_part/10; $exp=$exp+1;}
  my $eps = 1000.*10**-&float_precision;
  if ($leading_part>.9 && abs($leading_part-nearest_int($leading_part))<$eps) {
    $leading_part = nearest_int($leading_part);
  }
  # But now more consistently apply the rule that the result should be >=1 and <10.
  if ($leading_part<1.0) {$leading_part=$leading_part*10; $exp=$exp-1;}
  if ($leading_part>=9.99999) {$leading_part=$leading_part/10; $exp=$exp+1;}
  
  if ($exp==1 || $exp==2 || $exp== -1 || $exp== -2) {$leading_part=$leading_part*10**$exp; $exp=0;}
  
  if ($exp==0) {return $sn.$leading_part;}
  if ($leading_part eq "1" && $exp!=0) {return $sn."10^" . $exp;}
  return $sn . $leading_part . "*10^" . $exp;
}

BEGIN {
  my $initialized = 0;
  my $private_float_precision; # number of decimal digits
  sub float_precision {
    if ($initialized) {return $private_float_precision;}
    my $x = 1.;
    my $max = 100;
    for (my $n=0; $n<=$max; $n++) {
      my $y = $x;
      $y = $y + 10**-$n;
      if ($y==$x) {$private_float_precision=$n+1; return $private_float_precision;}
    }
    $private_float_precision=$max+1;
    return $private_float_precision;
  }
}

1;
