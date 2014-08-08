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

package Measurement;

use strict vars;

use Rational;
use Units;
use Math::Complex;
use Crunch;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&promote_to_measurement &number_cplx &sqrtm &atomize);


# The Measurement object consists of a complex floating point number along with
# a hash giving the units, e.g. 9.8 m/s2 becomes 9.8 along with
# {m=>1,s=>-2}. The exponents attached to the units are Rationals.
# Some operators are overloaded.
# Currently doesn't overload functions, so Eval has to handle those by hand.
# Can't overload exponentiation, because it needs to be able to figure out
# whether the exponent is unitless, which it can't do without knowing
# about the system of units we're using.

use overload '+' => \&add,'-' => \&subtract,'*' => \&mult,'/' => \&div, 
		 '""' => \&stringify, 'abs'=>\&absval, '=='=>\&equals;


# Call new() with a real or complex number, and a Units object. 
# If you don't supply second arg, it's unitless.
sub new {
  my $classname = shift;
  my $self = {};
  bless($self,$classname);
  $self->number(shift);
  $self->nonstandard_flag(0);
  if (@_) {
    $self->units(shift);
  }
  else {
    $self->units(Units->new());
  }
  $self->simplify;
  return $self;
}

sub parse {
  my $x = shift;
  #print "Measurement::parse $x\n";
  return Measurement->new($x) unless $x =~ m/([^\s]+)\s+([^\s]+)/;
  # Has units:
  #print "units...\n";
  return Measurement->new($1,parse_units(TEXT=>$2,DEBUG=>0));
}

sub number {
  my $self = shift;
  # Have to handle the case where this is not really a syntactically valid number. The parser will, for instance, parse "(2" into RPN like '(' '2'. That's
  # a bug in the parser, but anyway we don't want to crash if that gets handed to us. This also gets called a lot simply
  # to read or set a number that has already been parsed.
  if (@_) {
    my $x = shift;
    if (ref($x) eq '' && ($x & ~$x)) { # It hasn't been parsed yet. The second clause is a trick to test whether it's a string.
      if ($x =~ m/^[0-9\.\+\-e]+$/o) { # This clause is for efficiency.
        $self->{NUMBER} = $x+0.;
      }
      else { # the less common case, where it's complex
        if ($x =~ m/^[0-9\.\+\-ie]+$/) { # loose check for syntactically valid number
          if (!(ref($x) eq "" && $x eq "?")) {
            $x=Crunch::demote_cplx($x); # Some things might pass the syntax check above, e.g., "2..", and demote_cplx will then return zero.
          }
          $self->{NUMBER} = $x;
        }
        else {
          $self->{NUMBER} = '?';
        }
      }
    }
    else { # It's not a string that needs to be parsed;
      $self->{NUMBER} = Crunch::demote_cplx($x);
    }
  }
  return $self->{NUMBER};
}


sub number_cplx {
  my $self = shift;
  if (ref($self) eq "Math::Complex") {return $self;}
  my $value = $self;
  if (ref($self) eq "Measurement") {$value= $self->number;}
  return Crunch::promote_cplx($value);
}

sub is_real {
  my $self = shift;
  my $z = $self->number_cplx();
  return Im($z)==0;
}

sub is_positive_real {
  my $self = shift;
  my $z = $self->number_cplx();
  return Im($z)==0 && Re($z)>0;
}

sub is_zero {
  my $self = shift;
  if (ref($self) ne "Measurement") {
    return $self==0;
  }
  else {
    return $self->number==0;
  }
}



sub units {
  my $self = shift;
  if (@_) {$self->{UNITS} = shift;}
  return $self->{UNITS};
}

sub mult {
  my ($a,$b) = @_;
  return Measurement->new((($a->number)*($b->number)),(($a->units)*($b->units)));
}

sub div {
  my ($a,$b) = @_;
  return Measurement->new((($a->number)/($b->number)),(($a->units)/($b->units)));
}

sub expon {
  my ($a,$b,$unit_def_ref) = @_;
  my $bb = $b->atomize($unit_def_ref);
  return "" unless $bb->is_manifestly_unitless;
  my $p = Rational->new($bb->number);
  if ($a->is_manifestly_unitless) {
    my $n =  Crunch::demote_cplx(Crunch::promote_cplx($a->number)**Crunch::promote_cplx($b->number));
    return Measurement->new($n,Units->new);
  }
  if (ref($p) eq "Rational") {
    my $n =  Crunch::demote_cplx(Crunch::promote_cplx($a->number)**Crunch::promote_cplx($b->number));
    my $u = Units::to_power($a->units,$p);
    return Measurement->new($n,$u);
  }
  # The following only happens in some pretty goofy cases, e.g. (1 ft/1 in)^i
  if ($a->reduces_to_unitless($unit_def_ref)) {
    my $aa = $a->atomize($unit_def_ref);
    my $n =  Crunch::demote_cplx(Crunch::promote_cplx($aa->number)**Crunch::promote_cplx($b->number));
    return Measurement->new($n,Units->new);
  }
  return "";
}

# Return $a converted into the same units as $b. The number
# in $b is ignored.
sub convert {
  my ($a,$b,$unit_def_ref) = @_;
  return undef unless defined $a && defined $b;
  my $aa = $a->atomize($unit_def_ref);
  my $bb = Measurement->new(1.,$b->units);
  $bb = $bb->atomize($unit_def_ref);
  #print "in convert abaabb = $a $b $aa $bb\n";
  return Measurement->new(($aa->number)/($bb->number),$b->units);
}


sub sqrtm {
  my ($x,$unit_def_ref) = @_;
  return expon(promote_to_measurement($x),Measurement->new(0.5),$unit_def_ref);
}

sub add {
  my ($a,$b) = @_;
  if (($a->units)==($b->units)) {
    return Measurement->new(($a->number)+($b->number),($a->units));
  }
  else {
    return;
  }
}

sub subtract {
  my ($a,$b) = @_;
  if (($a->units)==($b->units)) {
    return Measurement->new(($a->number)-($b->number),($a->units));
  }
  else {
    return;
  }
}

sub equals {
  my ($a,$b) = @_;
  if (($a->units)==($b->units)) {
    return ($a->number_cplx==$b->number_cplx);
  }
  else {
    return;
  }
}


sub absval {
  my $self = shift;
  $self->number(abs($self->number));
  return $self;
}

sub simplify {
  my $self = shift;
  my $n = $self->number;
  my $r = ref($n);
  my $u = $r eq "" && $self->number eq "?"; # numerical part is undefined
  if ($r ne "Math::Complex" && !$u) { # if not complex, promote to complex
    $self->number(Math::Complex->new($n,0));
  }
  $self->units->simplify;
}

sub stringify {
  my $self = shift;
  my $debug = 0;

  if ($self->belongs_to_nonstandard_set('undef')) {return $self->stringify_nonstandard_type()}
    # There's no syntax that would allow us to construct things like +inf kilograms, so no need to allow
    # for that. 

  my $result = "";
  if (Eval::is_undef($self)) {
	  $result = "?";
  }
  else {
	  my $n = promote_cplx($self->number);
	  if ($debug) {print "n=$n\n";}
	  my $real = Re($n);
	  my $imag = Im($n);
	  if ($debug) {print "re=$real, im=$imag\n";}
    # pre and pim are prettified, printable versions of real and imag
	  my $pre = Crunch::prettify_floating_point($real);
	  my $pim = Crunch::prettify_floating_point($imag);
	  if ($debug) {print "pre=$pre, pim=$pim\n";}
	  if ($pim eq "-1") {$pim="-";} # Print as "-i", not "-1i"
  	if ($pim eq "1") {$pim=""} # Print as "i", not "1i"
	  my $eps = &Spotter::get_tol;
	  if ($debug) {print "eps=$eps\n";}
    # zre=is real part zero, zim=is imag part zero
	  my $zre = ($real==0) || ($imag!=0 && abs($real/$imag)<$eps);
	  my $zim = ($imag==0) || ($real!=0 && abs($imag/$real)<$eps);
	  if ($debug) {print "zre=$zre zim=$zim\n";}
	  if ($zim && $zre) {$result = "0"}
	  if ($zim && !$zre) {$result = $pre}
	  if (!$zim && $zre) {$result = $pim."i"}
	  if (!$zim && !$zre) {
		  if ($imag>0) {
		    $result = $pre."+".$pim."i";
		  }
		  else {
		    $result = $pre.$pim."i";
		  }
	  }
  }
  my $u = "".$self->units;
  if ($u ne "") {$result = $result . " " . $u;}
  return $result;
}


sub cplx_to_string {
  my $x = shift;
  if ($x==cplx(0,0)) {
    return "0";
  }
  else {
    return "$x";
  }
}

sub promote_to_measurement {
  my $self = shift;
  if (ref($self) eq "Measurement") {return $self;}
  if (!defined $self) {return undef}
  return Measurement->new($self);
}

sub demote_cplx {
  my $self = shift;
  my $x = Crunch::demote_cplx($self->number);
  $self->number($x);
}

sub is_manifestly_unitless {
  my $self = promote_to_measurement(shift);
  return $self->units->is_manifestly_unitless;
}


sub compatible_units {
  my ($a,$b,$unit_def_ref) = @_;
  # As a special case, a 0 without explicit units is considered to be compatible in terms of units with any number
  # that has units. For example, if a question asks for a velocity, and the correct answer happens to be 0, we want
  # to give the right response both when the student puts in 0 (correct) and when the student puts in x/t (incorrect,
  # and not incorrect because of units).
  unless (defined $a && defined $b) {return undef}
  if (($a->is_zero && $a->reduces_to_unitless) || ($b->is_zero && $b->reduces_to_unitless)) {return 1}
  return reduces_to_unitless(Measurement->new(1,$a->units/$b->units),$unit_def_ref);
}

# cf Units::is_manifestly_unitless and Measurement::is_manifestly_unitless
sub reduces_to_unitless {
  my $self = promote_to_measurement(shift);
  my $unit_def_ref = shift;
  my $m = $self->atomize($unit_def_ref);
  if (Spotter::is_null_string($m)) {return ""}
  return Units::is_manifestly_unitless($m->units);
}

# See also Units->prettify_mksc
sub prettify_units {
  my $self = promote_to_measurement(shift);
  my $unit_def_ref = shift;
  my $m = $self;
  my $did = 0;
  my $result = $m;
  
  # Does it reduce to unitless?
  if ($self->reduces_to_unitless($unit_def_ref)) {
    $result= convert($m,Measurement->new(1),$unit_def_ref);
    $did = 1;
  }
  
  if (!$did) {
	  # Try making into meter, kilogram, second, and Coulomb:
	  my $mksc = $self->atomize($unit_def_ref);
	  #print "in prettify_units: self=$self, mksc = $mksc\n";
	  my %u = $mksc->units->units;
	  if (!exists $u{"kg"}) {$u{"kg"}=Rational->new(0);}
	  if (exists $u{"g"}) {
		$mksc->number($mksc->number * 0.001**$u{"g"}->float);
		$u{"kg"} = $u{"kg"} + $u{"g"};
		delete $u{"g"};
		$mksc->units(Units->new(\%u));
	  }
	  $mksc->units($mksc->units->prettify_mksc); # Does nothing unless it's already mgsC.
	  if ($mksc->units->ugliness < $m->units->ugliness) {$result = $mksc;}
  }
  
  if (Eval::is_undef($m)) {$result = Eval::make_undef($result);}
  return $result;
}

# Reduce to units that aren't defined in terms of other units.
# Normally this means m, s, g, C.
# Returns the result -- doesn't do anything to the 1st arg.
sub atomize {
  my $self = shift;
  my $unit_def_ref = shift;
  #print "atomizing $self\n";
  my $recursion_depth;
  my $m = Measurement->new($self->number,$self->units);
  if (@_) {
    $recursion_depth = shift;
  }
  else {
    $recursion_depth = 0;
  }
  if ($recursion_depth>10) {return ""}
  if (is_manifestly_unitless($m)) {return $m}
  my %unit_def = %$unit_def_ref;
  $m->units->simplify;
  my %hash = $m->units->units;
  my $result = Measurement->new($m->number);
  my $f;
  my $did_any = 0;
  foreach my $u (keys %hash) {
    my $p = $hash{$u};
    my $prefix_value;
    my ($prefix,$base_unit) = parse_prefixed_unit($u,$unit_def_ref,\%Spotter::standard_prefixes);
    #print "prefix=$prefix, base_unit=$base_unit\n";
    if ($prefix ne "") {
      $prefix_value = $Spotter::standard_prefixes{$prefix};
      $u = $base_unit;
    }
    else {
      $prefix_value = 0;
    }
    if (exists($unit_def{$u}) && $unit_def{$u} ne "") {
      my $def = $unit_def{$u};
      my $conversion = Eval::lex_parse_and_eval($def);
      #print "conversion = $conversion\n";
      $f = expon($conversion,Measurement->new($p->float),$unit_def_ref); 
      $did_any = 1;
    }
    else {
      #print "basic u=$u p=$p\n";
      $f = Measurement->new(1,Units->new({$u=>$p}));
    }
    #print "f=$f\n";
    $result = $result * $f;
    if ($prefix_value != 0) {
      $result->number($result->number * 10**($prefix_value*$p->float));
    }
  }
  if ($did_any) {
    $result = atomize($result,$unit_def_ref,$recursion_depth+1);
  }
  return $result;
}

# The following assumes prefixes are one character.
sub parse_prefixed_unit {
  my ($u,$unit_def_ref,$prefix_hash_ref) = @_;
  my $prefix = substr($u,0,1);
  if (exists $$prefix_hash_ref{$prefix} && exists $unit_def_ref->{substr($u,1)}
         && exists $Spotter::accepts_metric_prefixes{substr($u,1)}) {
    return ($prefix,substr($u,1));
  }
  else {
    return ("",$u);
  }
}

sub nonstandard_flag { # private method
  my $self = shift;
  if (@_) {$self->{NONSTANDARD_FLAG} = shift;}
  return $self->{NONSTANDARD_FLAG};
}

sub set_nonstandard_set { # public method
  my $self = shift;
  my $set = shift; # 'defined','undef','inf','+inf', or '-inf'
  $self->nonstandard_flag($self->nonstandard_name_to_hex($set));  
}

sub nonstandard_name_to_hex { # private method
  my $self = shift;
  my $set = shift; # 'defined','undef','inf','+inf', or '-inf'
  return {'defined'=>0x0,'undef'=>0x8,'inf'=>0xc,'+inf'=>0xe,'-inf'=>0xf}->{$set};
}

sub stringify_nonstandard_type { # public method
  my $self = shift;
  my $f = $self->nonstandard_flag();
  return {0x0=>'defined',0x8=>'undef',0xc=>'inf',0xe=>'+inf',0xf=>'-inf'}->{$f};
}

sub is_nonstandard { # public method
  my $self = shift;
  return $self->nonstandard_flag()!=0;
}

sub same_nonstandard_type { # public method
  my $self = shift;
  my $other = shift;
  return $self->nonstandard_flag()==$other->nonstandard_flag();
}

sub belongs_to_nonstandard_set { # public method
  my $self = shift;
  my $set = shift; # 'defined','undef','inf','+inf', or '-inf'
  my $f = $self->nonstandard_flag();
  if ($set eq 'defined') {return $f==0}
  if ($set eq 'undef')   {return ($f & 0x8)!=0}
  if ($set eq 'inf')     {return ($f & 0x4)!=0}
  if ($set eq '+inf')    {return $f==0xe}
  if ($set eq '-inf')    {return $f==0xf}
  return undef;
}

#==================================================================
#==================================================================
#==================================================================

1;
