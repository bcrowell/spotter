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

package Units;
use strict vars;

use Rational;
use Spotter;
use utf8;


use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&parse_units &foo);

# A Units object stores the units of a physical quantity,
# e.g. m/s2 becomes (m=>1,s=>-2). The exponents attached to the units are Rationals.

use overload '*' => \&mult,'/' => \&div,
		 '""' => \&stringify, '=='=>equals;


# Pass hash by reference. If hash is anonymous, this means you can use the {...} syntax.
# Integers are automatically made into Rationals.
# If no arg given, it's unitless.
sub new {
  my $classname = shift;
  my $self = {};
  bless($self,$classname);
  
  if (@_) {
    my $hash_ref = shift;
    $self->units($hash_ref);
  }
  else {
    $self->units({});
  }
  $self->simplify;
  return $self;
}

# Raise to a rational power.
sub to_power {
  my ($x,$p) = @_;
  my %x_hash = $x->units;
  my %y_hash;
  
  foreach (keys %x_hash) { 
    $y_hash{$_} = $x_hash{$_}*$p;
  }
  my $y = Units->new(\%y_hash);
  $y->simplify;

  return $y;
  
}

# If setting units, pass by reference. If getting, it's dereferenced.
sub units {
  my $self = shift;
  if (@_) {
    my $hash_ref = shift;
    $self->{UNITS} = $hash_ref;
  }
  my $hash_ref = $self->{UNITS};
  return %$hash_ref;
}


sub mult {
  my ($a,$b) = @_;
  my %c_hash = {};
  my %a_hash = $a->units;
  my %b_hash = $b->units;
  
  # Units only in a:
  foreach (keys %a_hash) { $c_hash{$_} = $a_hash{$_} if (!exists $b_hash{$_}); }
  
  # Units only in b:
  foreach (keys %b_hash) { $c_hash{$_} = $b_hash{$_} if (!exists $a_hash{$_}); }
  
  # Units in both a and b:
  foreach (keys %a_hash) { 
    if (exists $b_hash{$_}) {
      $c_hash{$_} = $a_hash{$_}+$b_hash{$_};
    }
  }
  
  my $c = Units->new(\%c_hash);
  $c->simplify;
  return $c;
}

sub div {
  my ($a,$b) = @_;
  return $a * invert($b);
}

sub equals {
  my ($a,$b) = @_;
  return is_manifestly_unitless($a/$b);
}

# cf Measurement::reduces_to_unitless
sub is_manifestly_unitless {
  my ($a) = @_;
  $a->simplify;
  my %h = $a->units;
  return keys(%h)==0;
}

sub invert {
  my ($a) = @_;
  my %a_hash = $a->units;
  foreach (keys %a_hash) {
    $a_hash{$_} = Rational->new(0)-$a_hash{$_};
  }
  my $b = Units->new(\%a_hash);
  $b->simplify;
  return $b;
}


sub simplify {
  my $self = shift;
  my %hash = $self->units;
  foreach (keys %hash) {
    my $p = $hash{$_};
    if (! ref $p) {
      $hash{$_} = Rational->new($p,1);
    }
    $hash{$_}->simplify;
    if (($hash{$_}->numer)==0) { # By this point, it's guaranteed to be a Rational.
      delete($hash{$_});
    }
  }
  $self->units(\%hash);
}

sub stringify {
  my $self = shift;
  $self->simplify;
  my %h = $self->units;
  my $unitdot = ".";
  my $s = "";
  foreach (keys %h) {
    my $p = $h{$_};
    if ($p>Rational->new(0)) {
      if (length $s>0) {
        $s = $s . $unitdot;
      }
      $s = $s . $_;
      $s = $s . $p unless ($p == (Rational->new(1)));
    }
  }
  my $did_slash = 0;
  my $write_as_neg_exp = (length $s == 0);
  foreach (keys %h) {
    if ($h{$_}<Rational->new(0)) {
      if ($write_as_neg_exp) {
        $s = $s . $_ . $h{$_};
      }
      else {
        if (!$did_slash) {
          $s = $s . "/";
        }
        if ($did_slash) {
          $s = $s . $unitdot;
        }
        my $p = $h{$_};
        $p = Rational->new(0)-$p;
        $s = $s . $_;
        $s = $s . $p unless ($p == (Rational->new(1)));
        $did_slash = 1;
      }
    }
  }  
  return $s;  
}

# Bare-bones routine to prettify units that are already in terms
# of meters, kilograms, seconds, and Coulombs, with no prefixes.
# If the units aren't already pure mksC, we simply return the original
# units without simplifying, i.e. it's always safe to call this routine.
# Since there are no prefixes, we don't need to do any conversion
# factors. We also don't need to be told the unit definitions.
sub prettify_mksc {
  my $self = shift;
  my %h = $self->units;
  my ($m,$kg,$s,$c) = ("0/1","0/1","0/1","0/1");
  foreach my $u (keys %h) {
    if ($u ne "m" && $u ne "kg" && $u ne "s" && $u ne "C") {return $self;}
  }
  if (exists $h{"m"}) {$m = $h{"m"}->numer."/".$h{"m"}->denom;}
  if (exists $h{"kg"}) {$kg = $h{"kg"}->numer."/".$h{"kg"}->denom;}
  if (exists $h{"s"}) {$s = $h{"s"}->numer."/".$h{"s"}->denom;}
  if (exists $h{"C"}) {$c = $h{"C"}->numer."/".$h{"C"}->denom;}
  if ($c eq "0/1") {
	  if ($kg eq "1/1") {
		  if ($m eq "1/1") {
			  if ($s eq "-2/1") {return Units->new({"N"=>1});}
		  }
		  if ($m eq "2/1") {
			  if ($s eq "-2/1") {return Units->new({"J"=>1});}
			  if ($s eq "-3/1") {return Units->new({"W"=>1});}
		  }
	  } # end if kg^1
  } # end if C^0
  if ($c eq "1/1") {
	  if ($kg eq "0/1") {
		  if ($m eq "0/1") {
			  if ($s eq "-1/1") {return Units->new({"A"=>1});}
		  }
	  } # end if kg^0
  } # end if C^1
  if ($c eq "-2/1") {
	  if ($kg eq "1/1") {
		  if ($m eq "2/1") {
			  if ($s eq "-1/1") {return Units->new({chr(hex("3a9"))=>1});} # Omega for ohms
			  if ($s eq "0/1") {return Units->new({"H"=>1});} 
		  }
	  } # end if kg^0
  } # end if C^-2
  if ($c eq "2/1") {
	  if ($kg eq "-1/1") {
		  if ($m eq "-2/1") {
			  if ($s eq "2/1") {return Units->new({"F"=>1});} 
		  }
	  } # end if kg^0
  } # end if C^-2
  return $self; # Couldn't simplify.
}

sub ugliness {
  my $self = shift;
  my %h = $self->units;
  my $score = 0;
  foreach my $u (keys %h) {
    my $p = $h{$u};
    if ($p->is_integer) {
      if ($p->numer == 1 || $p->numer == -1) {
        $score = $score + 1;
      }
      else {
        $score = $score + 2;
      }
    }
    else {
      $score = $score + 3;
    }
  }
  return $score;
}



#==================================================================
#==================================================================
#==================================================================
#==================================================================
#==================================================================
#==================================================================


# Parse an expression describing units, such as m/s, year3/2, or Btu/ft-lb.
# Unlike the expression parser in the Parse module, this one automatically
# lexes and evaluates for you. There is no fancy error handling, because we assume
# we wouldn't have been passed this expression unless the expression
# parser had already detected that it was syntactically correct.
# *, -, and . are all synonyms for multiplication
# / has lower priority than multiplication
sub parse_units{
  my %args = (
    TEXT		=> "",
    DEBUG		=> 0,
    @_,
  );
  my $debug = $args{DEBUG};
  my $text = $args{TEXT};
  if ($debug) {print "in parse_units\n";}
  my @tokens = Units::lex(EXPRESSION=>$text,DEBUG=>$debug);
  if ($debug) {
	print "tokens = ";
	foreach my $token(@tokens) {
	  print "'$token' ";
	}
	print "\n";
  }
  my $tokens_ref = \@tokens;
  my $rpn_ref = do_parse(TOKENS=>$tokens_ref,DEBUG=>$debug);
  my @rpn = @$rpn_ref;
  if ($debug) {
	print "rpn = ";
	foreach my $token(@rpn) {
	  print "'$token' ";
	}
	print "\n";
  }
  return eval_units_rpn(@rpn);
}

sub eval_units_rpn {
  my @rpn = @_;
  my @stack = ();
  my $debug = 0;
  foreach my $token (@rpn) {
    my $did = 0;
    if ($debug) {print "token=$token\n";}
    if ($token eq "." || $token eq "-") {$token="*";}
    if ($token eq "*" || $token eq "/" || $token eq "**") {
      my $b = pop(@stack); # second operand is on top
      my $a = pop(@stack);
      my $result;
      if ($token eq "*") {$result = $a*$b;}
      if ($token eq "/") {$result = $a/$b;}
      if ($token eq "**") {$result = to_power($a,$b);}
      push @stack,$result;
      $did = 1;
    }
    if (!$did && $token =~ m/^(\-?\d+)((\/\d+)?).*/) {
      my $num = $1;
      my $den = substr($2,1);
      if ($debug) {print "num,den=$num,$den\n"}
      if ($den eq "") {
        push @stack,Rational->new($num);
      }
      else {
        push @stack,Rational->new($num,$den);
      }
      $did = 1;
    }
    if (!$did) {
      if ($debug) {print "basic token, $token\n";}
      push @stack,Units->new({$token=>1});
    }
  }
  my $result = pop(@stack);
  if ($debug) {print "done evaluating, result=$result, ref=".ref($result)."\n";}
  return $result;
}

sub do_parse{
  my %args = (
    TOKENS		=> [],
    DEBUG		=> 0,
    PASS		=> 0,
    FROM		=> 0,
    TO			=> -1,
    @_
  );
  my $tokens_ref = $args{TOKENS};
  my $debug = $args{DEBUG};
  my $pass = $args{PASS};
  my $from = $args{FROM};
  my $to = $args{TO};
  my $k = $#$tokens_ref; # number of tokens minus one
  if ($to == -1) {$to=$k;}
  my @rpn = ();
  my @ops_list = ("(/)",	"(\\*|\\.|\\-)");
  my $ord = 	 (1,			1,)[$pass];
  	# ord=1 for left associativity, ord=2 for right
  my $n_passes = $#ops_list + 1;
  my $ops = $ops_list[$pass];
  my @parens_stack = ();
  my @rpn = ();
  my ($start,$finish,$step,$n_nonwhite,$n_nonwhite_outside,$last_nonwhite_token_was_binary_op,
  	$last_token_was_outside_parens,$parsed,$rp,$right_is_null,$left_is_null,
  	$first_nonwhite_token,$last_nonwhite_token,
  	$leftmost_nonwhite_token,$rightmost_nonwhite_token,
  	$is_whitespace,$outside_parens,$right_rpn_ref);
  	
  	if ($k<0) {print "internal error  1 in Units::parse"; return "";}

  	#Note that, in the following, the lexer has guaranteed us no more than one white-
  	#space character in a row:
  	if (Spotter::is_white($tokens_ref->[$from])) {$from++;}
  	if (Spotter::is_white($tokens_ref->[$to])) {$to--;}
    if ($ord == 1) { ($start,$finish,$step) = ($to,$from,-1); }
    else { ($start,$finish,$step) = ($from,$to,1); }
    # In the following, start and finish are already guaranteed to
    # be nonwhite:
    my ($leftmost_nonwhite_index,$rightmost_nonwhite_index);
    if ($ord==1) {
      ($leftmost_nonwhite_token,$rightmost_nonwhite_token,$leftmost_nonwhite_index,$rightmost_nonwhite_index)
      		=($tokens_ref->[$finish],$tokens_ref->[$start],$finish,$start);
    }
    else {
      ($leftmost_nonwhite_token,$rightmost_nonwhite_token,$leftmost_nonwhite_index,$rightmost_nonwhite_index)
      		=($tokens_ref->[$start],$tokens_ref->[$finish],$start,$finish);
    }

    $n_nonwhite = 0;
    $n_nonwhite_outside = 0;
    $last_nonwhite_token_was_binary_op = 0;
    $last_token_was_outside_parens = 1;
    $parsed = 0;    

    if ($debug) {print "parsing units, from=$from, to=$to, pass=$pass\n";}
    for (my $i=$start; ($finish-$i)*$step>=0 && !$parsed; $i += $step) {
      #if ($debug) {print "  from=$from, to=$to, pass=$pass, i=$i\n";}
      my $token = $tokens_ref->[$i];
      # First see if we're closing off some parens:
      if ($#parens_stack>=0
      		&& ((is_l_paren($token) && $ord==1) || (is_r_paren($token) && $ord==2))
      		&& !($token eq "|" && $parens_stack[$#parens_stack] ne "|")      ) {
        my $oldp = pop(@parens_stack);
        my $z = $oldp . $token;
        if (!($z eq "()" || $z eq ")(" || $z eq "[]" || $z eq "][" 
        		|| $z eq "{}" || $z eq "}{" || $z eq "||")) {
          print "internal error  2 in Units::parse"; return "";
          #if ($debug) {print "token=$token\n";}
        }
      }
      else {
        if ((Spotter::is_r_paren($token) && $ord==1) || (Spotter::is_l_paren($token) && $ord==2)) {
          push(@parens_stack,$token);
        }
      }
      $is_whitespace = Spotter::is_white($token);
      $outside_parens = $#parens_stack<0;
      if (!$is_whitespace) {++$n_nonwhite;}
      if (!$is_whitespace && $outside_parens) {++$n_nonwhite_outside;}
      if (!$is_whitespace && ((length $first_nonwhite_token) == 0)) {
        $first_nonwhite_token = $token;
      }
                
      if ($outside_parens && $token =~ m/^$ops$/)  {
        if ($debug) {print "from=$from, to=$to, pass=$pass, recognized token=$token\n";}
        my ($index_neighbor_left,$index_neighbor_right);
        $index_neighbor_right = $i+1;
        $index_neighbor_left = $i-1;
        $left_is_null = ($index_neighbor_left<$from);
        $right_is_null = ($index_neighbor_right>$to);
        if ($left_is_null || $right_is_null) {print "internal error  3 in Units::parse"; return "";}
        my $left_rpn_ref;
        if (!$left_is_null) {
          $left_rpn_ref
         	= do_parse(TOKENS=>$tokens_ref,DEBUG=>$debug,PASS=>0,
      					FROM=>$from,TO=>$index_neighbor_left);
          push(@rpn,@$left_rpn_ref);
      	}
        if (!$right_is_null) {
          $right_rpn_ref
      	    = do_parse(TOKENS=>$tokens_ref,DEBUG=>$debug,PASS=>0,
      					FROM=>$index_neighbor_right,TO=>$to);
          push(@rpn,@$right_rpn_ref);
      	}
        if (!$is_whitespace) {
            push(@rpn,$token);
        }
        $parsed = 1;
      } # end if found token
      # Remember stuff about this token for next time through loop:
      my $is_bin = ($token =~ m/(\/|\*|\.|\-)/);
      $last_nonwhite_token_was_binary_op = $is_bin || 
      	($is_whitespace && $last_nonwhite_token_was_binary_op);
      $last_token_was_outside_parens = $outside_parens;
      if (!$is_whitespace) {
        $last_nonwhite_token = $token;
      }
    } # end loop over tokens
    
    
    
    
  if (!$parsed) {
    if ($to-$from<=1) {
      for (my $i=$from; $i<=$to; $i++) {
        push(@rpn,$tokens_ref->[$i]);
      }
      if ($to-$from==1) {
        push(@rpn,"**");
      }
      $parsed = 1;
    }
    
    #Go inside parens:
    if (Spotter::is_l_paren($leftmost_nonwhite_token)
    	&& Spotter::is_r_paren($rightmost_nonwhite_token)) {
      my ($rpn_ref,$e)
       	= do_parse(TOKENS=>$tokens_ref,DEBUG=>$debug,PASS=>0,
      					FROM=>$leftmost_nonwhite_index+1,TO=>$rightmost_nonwhite_index-1);
      push(@rpn,@$rpn_ref);
	  $parsed = 1;
    }
    if (!$parsed && $pass<$n_passes-1) {
          my ($rpn_ref,$e)
         	= do_parse(TOKENS=>$tokens_ref,DEBUG=>$debug,PASS=>$pass+1,
      					FROM=>$from,TO=>$to);
          push(@rpn,@$rpn_ref);
          $parsed = 1;
    }
    if (!$parsed) {
      if ($debug) {print "from=$from, to=$to, pass=$pass, returning [0]=".$rpn[0]."\n";}
      print "internal error  4 in Units::parse"; return ""; # shouldn't happen
    }
  }
  return \@rpn;

}




#==================================================================
#==================================================================
#==================================================================


# Break up a units expression into tokens: units, exponents, and multiplication
# and division operators. Units with prefixes are kept as a single token.
# This code is closely based on the main expression parser.
# Assumes its input is already tidied: no illegal chars, no whitespace.
sub lex {
  my %args = (
    EXPRESSION	=> "",
    DEBUG		=> 0,
    @_
  );
  my $e = $args{EXPRESSION};
  my $debug = $args{DEBUG};
  my @errors = ();
  my @warnings = ();
  my @tokens = ();
  
  if ($debug) {print "in lex\n";}
  if ($debug) {print "Expression = $e\n";}
  if ($debug) {print "alpha = $Spotter::alpha_chars\n";}
  my $i = 0; # current offset into expression
  my $bail_out = 0;
  while ($i<length $e && !$bail_out) {
    if ($debug) {print "i=$i\n";}
    my $x = substr($e,$i);
    my $token;
    my $tokenized = 0;
    # ---- Recognize units:
    if ($x =~ m/^([$Spotter::alpha_chars]+).*/) {
      $token = $1;
      $tokenized = 1;
      if ($debug) {print "units, -$token-\n";}
    }
    # ---- Exponent:
    if (!$tokenized && $x =~ m/^((\-?\d+(\/\d+)?)).*/) {
      $token = $1;
      $tokenized = 1;
      if ($debug) {print "exp, -$token-\n";}
    }
    # ---- Operator: 
    if (!$tokenized && $x =~ m/^([\*\.\-\/]).*/) {
      $token = $1;
      $tokenized = 1;
      if ($debug) {print "op, -$token-\n";}
    }
    $i += length $token;
    if ($tokenized) {
      push(@tokens,$token);
      #print "pushing $token, " . length($e) . " len=" . (length $token) .", now i is $i\n"; #qwe
    }
    else {
      $bail_out = 1;
    }
  }
  return (@tokens);
}


1;
