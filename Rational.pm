#!/usr/bin/perl

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

package Rational;
use strict vars;

# The Rational class stores a rational number, i.e. the quotient of
# two integers. The operators +-*/ and a few more are overloaded,
# but cmp and <=> isn't (see below).
#
# I wanted to roll my own as a way to learn OO programming in Perl, but
# there are much better implementations out there, such as the Fraction
# package, available from CPAN.
#
# Currently, all methods assume arguments are supplied in simplified form,
# but external code shouldn't depend on the assumption that rationals are
# always simplified. In other words, don't use numer and denom directly,
# except when creating a new object.

use overload '+' => \&add,'-' => \&subtract,'*' => \&mult,'/' => \&div,
		 '""' => \&stringify, 'abs'=>absval, '<=>'=>compare;

# new(numer,denom), or new(int) or new(float)
# For new(float), an error can occur, in which case it returns a null string.
sub new {
  my $classname = shift;
  my $self = {};
  bless($self,$classname);
  my $error = 0;
  my $x;
  if ($#_ == 1) { # 2 args
    $self->numer(shift);
    $self->denom(shift);
  }
  else {
    $x = shift;
    if ($x==1) {return Rational->new(1,1)} # a very common trivial case, so do it here for efficiency
    if ($x<0) {return negation(Rational->new(-$x))}
    if (int($x)==$x) {return Rational->new($x,1)} # This also covers the case of $x=0, so if we get past this, $x>0.
    if (int(2*$x)==2*$x) {return Rational->new(2*$x,2)} # This is by far the most common nontrivial case, so handle it here for speed.
    my $did = 0;
    # At this point, we're guaranteed that $x is greater than 0 and less than 1, and is not a half-integer.
    for (my $j = 3; $j<=10 && !$did; $j++) {
      my $i = $x*$j;
      if (abs($i-int($i))<.0001 && abs($x-$i/$j)<0.0001) {
        $i = int($i+.5);
        #print "i=$i, j=$j\n";
        $self->numer($i);
        $self->denom($j);
        $did = 1;
      }
    }
    $error = !$did;
  }
  if (!$error) {
    $self->simplify;
    return $self;
  }
  else {
    return "";
  }
}

sub numer {
  my $self = shift;
  if (@_) {$self->{NUMER} = shift;}
  return $self->{NUMER};
}

sub denom {
  my $self = shift;
  if (@_) {$self->{DENOM} = shift;}
  return $self->{DENOM};
}

sub float {
  my $self = shift;
  return $self->numer/$self->denom;
}

sub stringify {
  my $self = shift;
  if ($self->denom != 1) {
    return $self->numer . "/" . $self->denom;  
  }
  else {
    return $self->numer;  
  }
}

sub absval {
  my ($a) = @_;
  return Rational->new(abs($a->numer),abs($a->denom));
}

sub add {
  my ($a,$b) = @_;
  my $c = Rational->new($a->numer*$b->denom+$a->denom*$b->numer,$a->denom*$b->denom);
  $c->simplify;
  return $c;
}

sub subtract {
  my ($a,$b) = @_;
  my $c = Rational->new($a->numer*$b->denom-$a->denom*$b->numer,
  			$a->denom*$b->denom);
  $c->simplify;
  return $c;
}

sub is_integer {
  my $self = shift;
  $self->simplify;
  return ($self->denom == 1);  
}

# doesn't work yet:
sub compare {
  my ($a,$b) = @_;
  my $c = $a-$b;
  #print "in compare, " . $a . "," . $b. "," . $c . "\n";
  return sign $c;
}

sub sign {
  my $self = shift;
  return ($self->numer) <=> 0; # assumes already simplified
}

sub negation {
  my $a = shift;
  if (!ref $a and $a eq '') {return ''}
  $a->numer(-($a->numer));  # assumes already simplified
  return $a;
}

sub mult {
  my ($a,$b) = @_;
  my $c = Rational->new($a->numer*$b->numer,$a->denom*$b->denom);
  $c->simplify;
  return $c;
}

sub div {
  my ($a,$b) = @_;
  my $c = Rational->new($a->numer*$b->denom,$a->denom*$b->numer);
  $c->simplify;
  return $c;
}

sub simplify {
  my $self = shift;
  # The first test is simply for efficiency:
  if ($self->denom==1) {
    return;
  }
  if ($self->numer==0) {
    $self->denom(1);
    return;
  }
  if ($self->denom<0) {
    $self->numer(-$self->numer);
    $self->denom(-$self->denom);
  }
  # mod operator messes up on negatives, so temporarily force positive:
  my $s = 1;
  if ($self->numer<0) {
    $s = -1;
    $self->numer(-$self->numer);
  }
  my $n = $self->numer;
  my $d = $self->denom;
  my $x = gcd($n,$d);
  $self->numer($n/$x);
  $self->denom($d/$x);
  $self->numer($s*$self->numer);
}

# from http://vipe.technion.ac.il/~shlomif/lecture/Perl/Newbies/lecture3/modules/importing/exporting.html
sub gcd
{
	my $a = shift;
	my $b = shift;
  if ($b > $a)	{
		($a, $b) = ($b , $a);
	}
  while ($a % $b > 0)	{
		($a, $b) = ($b, $a % $b);
	}
	return $b;
}



#==================================================================
#==================================================================
#==================================================================


1;
