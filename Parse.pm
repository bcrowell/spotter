#!/usr/bin/perl

#----------------------------------------------------------------
# Parsing module for Spotter.
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


package Parse;
use strict vars;
use Spotter;
use utf8;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

use Exporter;
$VERSION = 0.1;
@ISA = qw(Exporter);

@EXPORT = qw(&lex &parse);

#==================================================================
#==================================================================
#==================================================================

# The parser takes a tokenized expression and converts it to reverse
# Polish notation.
# Returns three references:
#        an array containing the RPN
#   a list of error messages
#   a hash of back-references for use when the evaluator needs to report an error
# The back-reference hash consists of strings that can be appended to an
# error code. The hash key is the same as the index of the operator in the
# RPN array.
#
# For internal use, we need to have a single copy of the RPN that is the same
# within recursive calls, so that the indices in the back refs can stay consistent.
# So when we recurse, we pass the optional RPN=> argument, and ignore the returned
# rpn for the subexpression.
#
# Unary - is handled as follows: 
#   First, we do a pass looking for binary + and -.
#   In this binary pass, we ignore any - that has a binary or unary operator
#   standing immediately to its left. 
#   Next, we do a pass looking for unary + and -.
#   In this pass, we ignore any + or - except a leading one. If we find such
#   a leading unary + or -, we push an implied 0 onto the RPN stack.
#   If we parse all the way through to the last pass
#
# See comments at the top of Parse.pm for information about how to add new operators.
#
# Notes on the bogus blank bug:
#  Example:
#    f = 1 m
#    g = 1 m
#    f+g -> 2 m
#    f + g -> error, because 'g' is treated as a unit
#  Normally, we use whitespace to detect units, e.g. 2 m means 2 meters, while 2m means
#  m*2. But in cases like f + g, we don't want the whitespace to have this significance.
#  There is now some code in lex() and parse() to handle this correctly.
# 
sub parse {
  my %args = (
    TOKENS                => [],
    RPN                        => [],
    BACK_REFS        => {}, # see format at top of Messages.pm
    CONSTANTS        => Spotter::standard_cons,
    FUNCTIONS        => Spotter::standard_funs,
    UNITS                => standard_units,
    PREFIXES        => standard_prefixes,
    VARIABLES        => [],
    DEBUG                => 0,
    PASS                => 0,
    FROM                => 0,
    TO                        => -1,
    UNITS_ALLOWED  => 1,
    @_
  );
  my $tokens_ref = $args{TOKENS};
  my $rpn_ref = $args{RPN};
  my $back_refs_ref = $args{BACK_REFS};
  my $cons_ref = $args{CONSTANTS};
  my $funs_ref = $args{FUNCTIONS};
  my $vars_ref = $args{VARIABLES};
  my $debug = $args{DEBUG};
  if ($debug) {print "parsing, DEBUG=>$debug\n";}
  my $pass = $args{PASS};
  my $from = $args{FROM};
  my $to = $args{TO};
  my $k = $#$tokens_ref; # number of tokens minus one
  my $units_allowed = $args{UNITS_ALLOWED};
  if ($to == -1) {$to=$k;}
  my $unitsref = $args{UNITS};
  if (!$units_allowed) {$unitsref = {}}
  my $prefixesref = $args{PREFIXES};
  my %units = %$unitsref;
  my %prefixes = %$prefixesref;
  my @cons_and_vars = (@$cons_ref,@$vars_ref); # Parser treats constants and vars the same.
  my $cons_and_vars_pat = array_to_pat(@cons_and_vars);
  my @funs = @$funs_ref;
  my @errors = ();
  #if (keys %units) {print "aaa<p>"} else {print "bbb<p>"}
  # See comments at the top of Parse.pm for information about how to add new operators.
  my @ops_list = ("(or|xor)","(and)","(not)","(eq|ne)",        "(,)",        "(\\-\\>)",        "(\\+|\\-)",        "(\\+|\\-)",        "(\\*|/|mod)",        "(\\*)",        "(\\^|\\*\\*)",        "funs",        "funs");
  my $ord =          (1,           1,      2,      1,         1,      1,              1,              1,              1,              1,              2,                 2,      1)[$pass];
          # ord=1 for left associativity like +, ord=2 for right like **
  my $implied =  (0,           0,      0,      0,         0,      0,              0,              0,              1,              1,              0,                 0,      0)[$pass];
          # Allow for implied multiplication.
  my $unary   =         (0,           0,      0,      0,         0,      0,              0,              1,              0,              0,              0,                 0,      0)[$pass];
        # implied zero for unary plus and minus
  my $postfix =         (0,           0,      0,      0,         0,      0,              0,              0,              0,              0,              0,                 0,      1)[$pass];
  my $unitmul =         (0,           0,      0,      0,         0,      0,              0,              0,              0,              1,              0,                 0,      1)[$pass];
  my $n_passes = $#ops_list + 1;
  my $ops = $ops_list[$pass];
  my $funs_pat = array_to_pat(@funs);
  my @parens_stack = ();
  my ($start,$finish,$step,$n_nonwhite,$n_nonwhite_outside,$last_nonwhite_token_was_binary_op,
          $last_token_was_outside_parens,$parsed,$rp,$right_is_null,$left_is_null,
          $first_nonwhite_token,$last_nonwhite_token,
          $leftmost_nonwhite_token,$rightmost_nonwhite_token,
          $is_whitespace,$implied_mult,$outside_parens,$right_rpn_ref,
          $is_binary_op,$dummy,$last_token,$index_of_last_nonwhite_token);
  my $units_pat = array_to_pat(keys(%units));
  my $prefix_pat = array_to_pat(keys(%prefixes));
  my $prefixable_units_pat = array_to_pat(sort {(length $b) <=> (length $a)} keys(%Spotter::accepts_metric_prefixes));
  my $unit_group_pat = make_unit_group_pat($prefix_pat,$units_pat,$prefixable_units_pat);
  $last_token = "";
  my $funs_pat = array_to_pat(@$funs_ref);

  if ($k<0) {push(@errors,"e:empty_expression:-2:-2:-2:-2"); return ($rpn_ref,\@errors);}

    #Note that, in the following, the lexer has guaranteed us no more than one white-
    #space character in a row:
    if (is_white($tokens_ref->[$from])) {$from++;}
    if (is_white($tokens_ref->[$to])) {$to--;}
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
    my $shallowest_level = 9999; # Avoid taking (2)*(3) and stripping off parens to make 2)*(3

    if ($debug) {print "parsing, from=$from, to=$to, pass=$pass\n";}
    for (my $i=$start; ($finish-$i)*$step>=0 && !$parsed; $i += $step) {
      #if ($debug) {print "  from=$from, to=$to, pass=$pass, i=$i\n";}
      my $token = $tokens_ref->[$i];
      # First see if we're closing off some parens:
      if ($#parens_stack>=0
                      && ((is_l_paren($token) && $ord==1) || (is_r_paren($token) && $ord==2))
                      && !($token eq "|" && $parens_stack[$#parens_stack] ne "|")) {
        my $oldp = pop(@parens_stack);
        my $z = $oldp . $token;
        if (!($z eq "()" || $z eq ")(" || $z eq "[]" || $z eq "][" 
                        || $z eq "{}" || $z eq "}{" || $z eq "||")) {
          push(@errors,"e:paren_mismatch:$from:$to:-1:-1:$token:$oldp");
          #if ($debug) {print "token=$token\n";}
        }
      }
      else {
        if ((is_r_paren($token) && $ord==1) || (is_l_paren($token) && $ord==2)) {
          push(@parens_stack,$token);
        }
      }
      if ($i!=$start && $i!=$finish && $#parens_stack+1<$shallowest_level) {
        $shallowest_level = $#parens_stack+1;
      }
      $is_whitespace = is_white($token);
      my $doing_non_infix_operator = 
        ($i!=$start)
        && !$last_nonwhite_token_was_binary_op
        && (
              (
                   is_op_fast($last_nonwhite_token,$funs_pat)
                      && is_postfix_op($last_nonwhite_token)
                    )
                  ||
                    (
                   is_op_fast($token,$funs_pat)
                      &&  !is_postfix_op($token)
                    )
                );
      if ($debug && $pass>=8) {print "pass $pass token=$token lt=$last_nonwhite_token dnio=$doing_non_infix_operator postfix_ops="
                              . $Spotter::postfix_ops{"!"}."="
                              . $Spotter::postfix_ops{$last_nonwhite_token}."= "
                              . is_op_fast($last_nonwhite_token,$funs_pat) . ","
                      . is_postfix_op($last_nonwhite_token) . ","
                      . is_op_fast($token,$funs_pat) . ","
                      . is_postfix_op($token). "==\n";}
      my $is_prefix_function = is_op_fast($token,$funs_pat) && !is_postfix_op($token);
      $implied_mult = $implied 
        && !$is_whitespace && ($i!=$start)
        && !$last_nonwhite_token_was_binary_op
        && !$doing_non_infix_operator
              && $last_token_was_outside_parens 
              && !$is_prefix_function;
              #&& !is_op_fast($token,$funs_pat);
      $outside_parens = $#parens_stack<0;
      #if ($debug) {print "  parens stack=$#parens_stack\n"}
      if (!$is_whitespace) {++$n_nonwhite;}
      if (!$is_whitespace && $outside_parens) {++$n_nonwhite_outside;}
      if (!$is_whitespace && ((length $first_nonwhite_token) == 0)) {
        $first_nonwhite_token = $token;
      }

      # Check for unary minus or plus:
      my $ignore_unary_minus = 0;
      if ($token eq "-" || $token eq "+") {
        #print "unary: ($token,$unary,$i,$leftmost_nonwhite_index)...";
        if ($unary) {
          if ($i!=$leftmost_nonwhite_index) { $ignore_unary_minus = 1; }
        }
        else {
          $ignore_unary_minus = 1;
          # Is the next nonwhite token to the left not an operator?
          my $done = 0;
          for (my $j=$i+$step; ($finish-$j)*$step>=0 && !$done; $j += $step) {
            my $neighbor = $tokens_ref->[$j];
            if (!is_white($neighbor)) {
              if (!is_op_fast($neighbor,$funs_pat)) {
                $ignore_unary_minus = 0;
              }
              $done = 1;
            }
          }
        }
        #print "$ignore_unary_minus\n";
      }

      #The following code checks last_token_was_outside_parens, not outside_parens,
      # because of cases where we have implied multiplication like (...)(...).
      #print "-=-= =$last_token_was_outside_parens=,=$outside_parens=\n";
      #print "-=-= =$ignore_unary_minus=,$ops,$token\n";
      if ($last_token_was_outside_parens && !$ignore_unary_minus
                      && (($ops ne "funs" && ($token =~ m/^$ops$/ || $implied_mult))
                       || ($ops eq "funs" && $token =~ m/^($funs_pat)$/ && is_postfix_op($token)==$postfix))      ) {
        #if (1) {print "  from=$from, to=$to, pass=$pass, recognized token=$token\n";}
        #if (1) {print "  implied_mult=$implied_mult\n"}
        my ($index_neighbor_left,$index_neighbor_right);
        $index_neighbor_right = $i+1;
        if (!$implied_mult) {
          $index_neighbor_left = $i-1;
        }
        else {
          $index_neighbor_left = $i;
        }
        $left_is_null = ($index_neighbor_left<$from);
        $right_is_null = ($index_neighbor_right>$to);
        if ($ops ne "funs" && $token ne "not" && $left_is_null &&!$unary) {
          push(@errors,"e:nothing_to_left:$from:$to:".($index_neighbor_left+1).":".(($index_neighbor_right-1)).":$token");
        }
        if ($ops ne "funs" && $right_is_null) {
          push(@errors,"e:nothing_to_right:$from:$to:".($index_neighbor_left+1).":".(($index_neighbor_right-1)).":$token");
        }
        #if ($debug) {print "  index_neighbor_left=$index_neighbor_left index_neighbor_right=$index_neighbor_right\n"}
              my $op_token_to_push;
        if ($implied_mult) {
          if ($last_token =~ m/^\s+$/) {
            $op_token_to_push = "__impliedmultwhitespace";
          }
          else {
            $op_token_to_push = "__impliedmult";
          }
          #Prohibit expressions like a2, which according to our syntax would mean 2a, but
          #probably indicates user wanted a^2.
          if (!$left_is_null && !$right_is_null) {
                          my $j = $index_neighbor_right;
                          if (is_white($tokens_ref->[$j]) && $j<$to) {$j++;}
                          my $k = $index_neighbor_left;
                          if (is_white($tokens_ref->[$k]) && $k>$from) {$k--;}
                          if ($tokens_ref->[$j] =~ m/^[\d\.].*/ && !($tokens_ref->[$k] =~ m/^[\d\.].*/)) {
                                my $num = $tokens_ref->[$j];
                                push(@errors,"e:implied_mult_num_on_right:$from:$to:-2:-2:$token:$num");
                          }
                   }
        }
        else {
          if (!$is_whitespace) {
            $op_token_to_push = $token;
          }
          else {
            #Is this an error?
          }
        }
        $parsed = 1;
        if ($op_token_to_push eq "*" || $op_token_to_push eq "__impliedmult" || $op_token_to_push eq "__impliedmultwhitespace") {
                  my $t = $last_nonwhite_token;
                  # Figure out whether it's a unit group, a variable.
                  my $token_to_left = "";
                  if ($index_of_last_nonwhite_token>0) {$token_to_left = $tokens_ref->[$index_of_last_nonwhite_token-1];}
                  my $matches_units_group = $units_allowed && is_unit_group($t,$unit_group_pat,$units_pat);
                  my $is_unitmul = (($op_token_to_push eq "__impliedmult" || 
                                  $op_token_to_push eq "__impliedmultwhitespace") && $matches_units_group);
                  if ($is_unitmul && !$unitmul) {$parsed=0;}
                  if ((!$is_unitmul) && $unitmul) {$parsed=0;}
                  #print "is_unitmul=$is_unitmul unitmul=$unitmul parsed=$parsed\n";
        }
        my ($e);
        if ($parsed) {
                        if (!$left_is_null) {
                          ($dummy,$e,$back_refs_ref)
                                = parse(TOKENS=>$tokens_ref,RPN=>$rpn_ref,CONSTANTS=>$cons_ref,FUNCTIONS=>$funs_ref,
                                                        VARIABLES=>$vars_ref,DEBUG=>$debug,PASS=>0,BACK_REFS=>$back_refs_ref,
                                                        FROM=>$from,TO=>$index_neighbor_left,UNITS=>$unitsref);
                          push(@errors,@$e);
                        }
                        if ($unary) {
                          push(@$rpn_ref,"__zero"); # special rpn token, subverts unit checking
                        }
                        if (!$right_is_null) {
                          ($dummy,$e,$back_refs_ref)
                                = parse(TOKENS=>$tokens_ref,RPN=>$rpn_ref,CONSTANTS=>$cons_ref,FUNCTIONS=>$funs_ref,
                                                        VARIABLES=>$vars_ref,DEBUG=>$debug,PASS=>0,BACK_REFS=>$back_refs_ref,
                                                        FROM=>$index_neighbor_right,TO=>$to,UNITS=>$unitsref);
                          push(@errors,@$e);
                        }
                        push(@$rpn_ref,$op_token_to_push);
                        if ($implied_mult) {
                          $back_refs_ref->{$#$rpn_ref} = ":$from:$to:-2:-2";
                        }
                        else {
                          $back_refs_ref->{$#$rpn_ref} = ":$from:$to:$i:$i";
                        }
        }
      } # end if found token
      # Remember stuff about this token for next time through loop:
      $last_nonwhite_token_was_binary_op = is_binary_op($token) || 
              ($is_whitespace && $last_nonwhite_token_was_binary_op);
      $last_token_was_outside_parens = $outside_parens;
      #if ($debug) {print "  end of loop, outside_parens=$outside_parens\n"}
      if (!$is_whitespace) {
        $last_nonwhite_token = $token;
        $index_of_last_nonwhite_token = $i;
      }
      $last_token = $token;
    } # end loop over tokens

  if (!$parsed) {
    if ($n_nonwhite_outside==1 && $n_nonwhite==1) {
      # We're parsing something that just consists of one token.
      my $t = $last_nonwhite_token;
      if ($t =~ m/^($funs_pat)$/) {
          push(@errors,"e:fun_without_arg:$from:$to:-1:-1:$t");
      }
      if (is_binary_op($t)) {
          push(@errors,"e:binary_without_args:$from:$to:-1:-1:$t");
      }
      # Figure out whether it's a unit group, a variable.
      my $token_to_left = "";
      if ($index_of_last_nonwhite_token>0) {$token_to_left = $tokens_ref->[$index_of_last_nonwhite_token-1];}
      my $second_to_left = "";
      if ($index_of_last_nonwhite_token>1) {$second_to_left = $tokens_ref->[$index_of_last_nonwhite_token-2];}
      my $matches_units_group = $units_allowed && is_unit_group($t,$unit_group_pat,$units_pat);
      my $could_be_vars = contains_only_cons_and_vars($t,$cons_and_vars_pat);
      my $wants_units = $token_to_left=~m/^\s+$/ && $matches_units_group && $second_to_left ne "" && $second_to_left=~m/^[\d\.]+$/;
                    # ...The last two clauses are a fix for the bogus blank bug (see above).
      #print "t=$t, cons_and_vars_pat=$cons_and_vars_pat,\n";
      #print "could_be_vars=$could_be_vars, token_to_left=---$token_to_left---\n";
      #print "index_of_last_nonwhite_token=$index_of_last_nonwhite_token\n";
      my $did = 0;
      my $prefix = "";
      if ($token_to_left eq "->") {$did=1; $prefix="units:";}
      if (!$did && $token_to_left=~m/^\s+$/ && $wants_units) {$did=1; $prefix="units:";} # expressions like 2 m (two meters)
      if (!$did && $matches_units_group && !$could_be_vars) {$did=1; $prefix="units:";}
      $t = $prefix . $t;
      if (is_l_paren($t) || is_r_paren($t)) {
        # This only occurs if we have a syntax error involving mismatched parens.
        push(@errors,"e:unbalanced_parens:$from:$to:-1:-1");
      }
      else {
        push(@$rpn_ref,$t) unless (is_l_paren($t) || is_r_paren($t)); 
      }
      $parsed = 1;
    }
    
    #Go inside parens:
    if (is_l_paren($leftmost_nonwhite_token)
            && is_r_paren($rightmost_nonwhite_token) && $shallowest_level>0) {
      #if ($debug) {print "  goin in parens, shallowest_level=$shallowest_level\n"}
      if ($leftmost_nonwhite_index+1>$rightmost_nonwhite_index-1) {
        push(@errors,"e:nothing_inside_parens:$leftmost_nonwhite_index:$rightmost_nonwhite_index:-1:-1");
      }
      else {
        my ($dummy,$e,$back_refs_ref)
                 = parse(TOKENS=>$tokens_ref,RPN=>$rpn_ref,CONSTANTS=>$cons_ref,FUNCTIONS=>$funs_ref,
                                              VARIABLES=>$vars_ref,DEBUG=>$debug,PASS=>0,BACK_REFS=>$back_refs_ref,
                                              FROM=>$leftmost_nonwhite_index+1,TO=>$rightmost_nonwhite_index-1,UNITS=>$unitsref,
                                              UNITS_ALLOWED=>$units_allowed);
          push(@errors,@$e);
          if ($leftmost_nonwhite_token eq "|") {push(@$rpn_ref,"abs");}
          }
          $parsed = 1;
    }
    if (!$parsed && $pass<$n_passes-1) {
          my ($dummy,$e,$back_refs_ref)
                 = parse(TOKENS=>$tokens_ref,RPN=>$rpn_ref,CONSTANTS=>$cons_ref,FUNCTIONS=>$funs_ref,
                                              VARIABLES=>$vars_ref,DEBUG=>$debug,PASS=>$pass+1,BACK_REFS=>$back_refs_ref,
                                              FROM=>$from,TO=>$to,UNITS=>$unitsref,
                                              UNITS_ALLOWED=>$units_allowed);
          push(@errors,@$e);
          $parsed = 1;
    }
    if (!$parsed) {
      if ($debug) {print "from=$from, to=$to, pass=$pass, returning [0]=".@$rpn_ref[0]."\n";}
      push(@errors,"e:parse_failed:$from:$to:-1:-1"); # shouldn't happen
    }
  }
  
  return ($rpn_ref,\@errors,$back_refs_ref);
}




#==================================================================
#==================================================================
#==================================================================


# Break up an expression into tokens, such as variable names, constants,
# functions, and operators. In general, the lexer works by taking the longest
# token it can find from the left, and then recursing. If the first choice
# causes an error on recursion, then we try another choice. Error handling only
# works correctly from the outermost recursion level (can only give
# an error code, not a correct back ref), so we just don't do a back
# ref when that happens.
#
sub lex {
  my @save_args = @_; # Saving this makes recursion simple.
  my %args = (
    EXPRESSION        => "",
    CONSTANTS        => standard_cons,
    FUNCTIONS        => standard_funs,
    UNITS                => standard_units,
    PREFIXES        => standard_prefixes,
    VARIABLES        => [],
    TOKEN_TO_LEFT => "",
    RECURSING   => 0,
    RECURSION_DEPTH => 0,
    N_RECURSIONS=> 0,
    DEBUG                => 0,
    UNITS_ALLOWED  => 1,
    @_
  );
  my $e = $args{EXPRESSION};
  my $consref = $args{CONSTANTS};
  my $funsref = $args{FUNCTIONS};
  my $varsref = $args{VARIABLES};
  my $units_allowed = $args{UNITS_ALLOWED};
  my $unitsref = $args{UNITS};
  if (!$units_allowed) {$unitsref = {}}
  my $prefixesref = $args{PREFIXES};
  my $token_to_left = $args{TOKEN_TO_LEFT};
  my $recursing = $args{RECURSING};
  my $recursion_depth = $args{RECURSION_DEPTH}+1;
  my $n_recursions = $args{N_RECURSIONS}+1;
  my $debug = $args{DEBUG};
  my @syms = (@$consref,@$funsref,@$varsref);
  my @errors = ();
  my @warnings = ();
  my @tokens = ();
  @syms = sort {(length $b) <=> (length $a)} @syms;
    # ...Sort them from longest to shortest. This way if something
    # like sinh appears in the expression, we match it to the function
    # sinh, rather than interpreting it as sin h.
  my $max_recursions = 2000;
  if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}

  my $syms_pat = array_to_pat(@syms);
  my %units = %$unitsref;
  my %prefixes = %$prefixesref;
  my $units_pat = array_to_pat(sort {(length $b) <=> (length $a)} keys(%units));
  my $prefixable_units_pat = array_to_pat(sort {(length $b) <=> (length $a)} keys(%Spotter::accepts_metric_prefixes));
  my $prefix_pat = array_to_pat(keys(%prefixes));
  my $unit_group_pat = make_unit_group_pat($prefix_pat,$units_pat,$prefixable_units_pat);
  my @cons_and_vars = (@$consref,@$varsref); # Lexer treats constants and vars the same.
  my $cons_and_vars_pat = array_to_pat(@cons_and_vars);

  #$debug = 1;

  if ($debug) {print "in Parse::lex, e=$e=, token_to_left=$token_to_left=, recursion_depth=$recursion_depth, n_recursions=$n_recursions<p>\n"}
  if ($debug) {print "unitsref=".$unitsref.", ref=".(ref $unitsref)."<p>\n"}
  if ($debug) {print "keys of unitsref=".(keys %$unitsref)."<p>"}

  if (!$recursing) {
          # The following is for security, so users can't do tricky things by
          # putting in backticks, etc.:
          my $old_e = $e;
          my $replace_illegal_with = " ";
          $e = eliminate_illegal_characters($e,$replace_illegal_with);
          if ($e ne $old_e) {push(@errors,"e:illegal_chars:0:-1:-2:-2:$replace_illegal_with")}
          
          # Strip leading and trailing whitespace:
          $e =~ m/^\s*(.*[^\s])?\s*$/;
          $e = $1;
          
          # Check for attempts to enter scientific notation as, e.g. 1e+3:
          if ($e =~ m/([\d\.]+)([eE])([\+\-]?)([\d]+)/) {
                if ($3 eq "")  {
                  push @errors,"w:illegal_scientific1:-2:-2:-2:-2:$1:$2:$3:$4";
                }
                else {
                   push @errors,"w:illegal_scientific2:-2:-2:-2:-2:$1:$2:$3:$4";
                }
          }
    }
    
    # The following block of code should theoretically be entirely optional. The idea here is to cut down
    # the complexity of the lexing immediately by breaking up the string at single characters
    # that are always independent tokens, such as +(). We don't do this with, e.g., /, -, or ^, because
    # they could be part of unit groups. In reality, it would cause problems if I turned off this block
    # of code. For instance, a student entered the following answer on a problem where x was not
    # a defined variable:
    #   sqrt(2)((m)*g*((sin theta)-(cos x)^2)*muk)/b
    # This caused the maximum depth of recursion to be exceeded, so he got the uninformative message
    # "empty expression." Enabling this code drastically reduces the amount of recursion, and fixes
    # the problem.
     if (1) {
      my $pat = '[\+\%\|\(\)\[\]\{\}]';
      # To minimize depth of recursion, we always try to split it as close as possible to
      # the middle of the expression.
      my $n = length $e;
      my $mid = int($n/2);
      for (my $i=0; $i<$n; $i++) {
        my $j;
        if ($i%2==0) {
          $j=$mid-$i/2;
        }
        else {
          $j=$mid+1+($i-1)/2;
        }
        if ($j>=0 && $j<$n) {
          my $c = substr $e,$j,1;
          if ($c=~m/($pat)/) {
            my $left = substr($e,0,$j); 
            my $right = substr($e,$j+1);
            #print "--$left--$c--$right--\n";
            if ($left ne "") {
              my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                 = lex(@save_args,EXPRESSION=>$left,RECURSION_DEPTH=>$recursion_depth,
                         TOKEN_TO_LEFT=>'',RECURSING=>1,N_RECURSIONS=>$n_recursions,
                         UNITS_ALLOWED=>$units_allowed);
              $n_recursions = $nr;
              if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
              while ($$recursion_tokens_ref[-1] eq "") {pop @$recursion_tokens_ref} #why?
              push (@tokens,@$recursion_tokens_ref);
              push (@errors,@$recursion_errors_ref);
				    }
            push @tokens,$c;
            if ($right ne "") {
              my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                 = lex(@save_args,EXPRESSION=>$right,RECURSION_DEPTH=>$recursion_depth,
                         TOKEN_TO_LEFT=>$c,RECURSING=>1,N_RECURSIONS=>$n_recursions,
                         UNITS_ALLOWED=>$units_allowed);
              $n_recursions = $nr;
              if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
              while ($$recursion_tokens_ref[-1] eq "") {pop @$recursion_tokens_ref} #why?
              push (@tokens,@$recursion_tokens_ref);
              push (@errors,@$recursion_errors_ref);
				    }
            return (\@tokens,\@errors,$n_recursions);
          }
        }
      }
    }

    # The following block of recursive code is entirely optional, but improves
    # the performance of the lexer significantly in certain cases, like expressions
    # that have a lot of undefined variables in them. The if(1) can be changed to
    # an if(0) without any consequences except to performance. Without this code, the lexer
    # just recurses from left to right, and it thinks decisions far off on the right can
    # affect ones near the left. But really, the only ambiguities are in groups
    # of alphanumeric characters that don't contain any operators, and each group
    # is independent of everything else. This is a unique technique for dealing
    # with a syntax that has implied multiplication -- wonder if anyone's thought of
    # it before?
    # I haven't figured out why I sometimes need to pop off null tokens.
    # One subtlety here: I don't want to split up expressions that are unit groups.
    if (1) {
                if ($e =~ m/($Spotter::symbol_pat)/) {
                  my $s = $1;
                  my $i = index $e,$s;
                  if ($i>=0 && (length $s)<(length $e)) { # Don't match the whole thing.
                        # Break the string into ($left,$s,$right), where $s matches the symbol pattern.
                        my $left = substr $e,0,$i; # will be null if $i is zero
                        my $right = substr $e,($i+length $s); # will be null if $i is zero
                        if (!(($s.$right) =~ m/^($unit_group_pat)/)) {
                                if ($left ne "") {
                                  my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                                                                = lex(@save_args,EXPRESSION=>$left,RECURSION_DEPTH=>$recursion_depth,
                                                                TOKEN_TO_LEFT=>$token_to_left,RECURSING=>1,N_RECURSIONS=>$n_recursions,
                                                                UNITS_ALLOWED=>$units_allowed);
                                  $n_recursions = $nr;
                                  if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
                                  while ($$recursion_tokens_ref[-1] eq "") {pop @$recursion_tokens_ref} #why?
                                  push (@tokens,@$recursion_tokens_ref);
                                  push (@errors,@$recursion_errors_ref);
                                }
                                if ($s ne "") {
                                  my $ttl = "";
                                  if ($left ne "") {$ttl=substr $left,-1}
                                  if ($ttl eq " " and (length $left)>=2 and !substr($left,-2,1)=~m/[\d\.]/) {
                                    $ttl = substr($left,-2,1); # fix for bogus blank bug (see above)
                                  }
                                  my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                                                                        = lex(@save_args,EXPRESSION=>$s,RECURSION_DEPTH=>$recursion_depth,
                                                                                        TOKEN_TO_LEFT=>$ttl,RECURSING=>1,N_RECURSIONS=>$n_recursions,
                                                                                        UNITS_ALLOWED=>$units_allowed);
                                  $n_recursions = $nr;
                                  if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
                                  while ($$recursion_tokens_ref[-1] eq "") {pop @$recursion_tokens_ref} #why?
                                  push (@tokens,@$recursion_tokens_ref);
                                  push (@errors,@$recursion_errors_ref);
                                }
                                if ($right ne "") {
                                  my $ttl = "";
                                  if ($s ne "") {$ttl=substr $s,-1}
                                  my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                                                                = lex(@save_args,EXPRESSION=>$right,RECURSION_DEPTH=>$recursion_depth,
                                                                                        TOKEN_TO_LEFT=>$ttl,RECURSING=>1,N_RECURSIONS=>$n_recursions,
                                                                                        UNITS_ALLOWED=>$units_allowed);
                                  $n_recursions = $nr;
                                  if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
                                  while ($$recursion_tokens_ref[-1] eq "") {pop @$recursion_tokens_ref} #why?
                                  push (@tokens,@$recursion_tokens_ref);
                                  push (@errors,@$recursion_errors_ref);
                                }
                                return (\@tokens,\@errors,$n_recursions);
                        }# end if not unit group
                  } # end if not the whole thing
                } # end if there were symbols
    } #end if feature is enabled
  
    my $fatal_error = 0;
    my %possible = ();
    # ---- Unit group:
    if ($units_allowed && $units_pat ne "" && $e =~ m/^($unit_group_pat)/s) {
      $possible{"u"} = $1;
    }
    
    my $require_units =  $token_to_left eq "->";
    # ---- Recognize symbols, i.e. constants, functions, and variables:
       # The longest possibility has key "s0", the second-longest "s1", etc.
       # This way we can test conveniently whether any "s" possibilities were found, by
       # checking whether s0 exists.
    if (!$require_units) {
      if ($e =~ m/^($syms_pat).*/s) {
        my $s = $1;
        for (my $i=0; $i<=(length $s)-1; $i++) {
          my $shortened = substr($s,0,length($s)-$i);
          if ($shortened =~ m/^($syms_pat).*/s) {$possible{"s$i"} = $shortened}
        }
      }
    }
    
    # ---- If it could be parsed as either a symbol or a unit group, decide
    #      which interpretation is preferred.
    #      In the following, the clause $token_to_left eq " " is because
    #      "2 m" means 2 meters, while "2m" means 2*m. Whitespace tokens have been
    #      converted to plain old blanks before recursion.
    #      We only prefer the unit interpretation if it's also at least as long
    #      as the alternative; otherwise stuff like "a sin x" gets parsed as
    #      (a)(units of s)(units of inches)(x).
    my $prefer_units = exists $possible{"u"} && ($require_units || $token_to_left eq " ");
    
    # ---- Exponentiation, or operators that are more than one character:
    if ($e =~ m/^(\*\*|\^|\-\>|eq|ne|and|or|not|xor|mod).*/s) {
      $possible{"2"} = $1;
    }
    # ---- Unrecognized symbols. We treat these as undefined variables.
    if ((!exists $possible{"u"}) && (!exists $possible{"s0"})  && (!exists $possible{"2"}) 
                                    && ($e =~ m/^($Spotter::symbol_pat).*/s)) {
      $possible{"?"} = $1;
      my $n = $#tokens + 1;
      push(@errors,"e:undef_sym:0:-1:$n:$n:$1"); # backref is broken by recursion
    }
    # ---- Numerical constant: 
    if ($e =~ m/^([\d\?]+)/) {
      $possible{"n"} = $1;
    }
    if ($e =~ m/^([\d\?]+\.[\d\?]*)/) {
      $possible{"n"} = $1;
    }
    if ($e =~ m/^([\d\?]*\.[\d\?]+)/) {
      $possible{"n"} = $1;
    }
    # ---- A single character, consisting of anything else but white space:
      # This happens for parentheses, single-character operators.
    my @glub = keys %possible;
    if (($#glub== -1) &&  ($e =~ m/^(\S).*/)) {
      $possible{"o"} = $1;
    }
    # ---- White space:
    if ($e =~ m/^(\s+).*/) {
      $possible{"w"} = $1;
    }
    # If there's more than one possible token, pick the longest one that works. If it's
    # a whitespace token, convert it to a blank. 
    # If either a unit group or a symbol is a possibility, we may override the length
    # criterion. If $require_units was set, then in the code above we didn't even
    # list symbols as possibilities. If $prefer_units is set, then we check for that first.
    # If neither is set, then we avoid units like the plague.
    my $longest_ever = "";
           foreach my $what (keys %possible) {
             my $t = $possible{$what};
             if ($debug) {print "$what:$t,";}
             if ((length $t)>(length $longest_ever)) {
                   $longest_ever = $t;
             }
        }
    if ($debug) {print "\n";}
    my $count = 0;
    while (1) {
        if ($debug) {print "count=$count\n"}
        $count = $count + 1;
                my $token = "";
                my $best_kind = "";
                my $cooked_token;
                foreach my $what (keys %possible) {
                  my $t = $possible{$what};
                  my $is_best = (    !$prefer_units 
                                  && (   ($what eq "u" && $token eq "")
                                      || ($what ne "u" && length $t>length $token)
                                      || $best_kind eq "u"  # Dump units, take symbols instead.
                                     )
                                ) 
                             || ($prefer_units && $what eq "u" && (length $t)>=(length $longest_ever));
                                             # ...the length clause keeps "a sin b" from becoming "(a)(s)(in)(b)".
                  if ($is_best) {
                        $best_kind = $what;
                        $token = $t;
                        if ($what eq "w") {
                          $cooked_token = " ";
                        }
                        else {
                          $cooked_token = $t;
                        }
                  }
                }
                if ((length $token)>=(length $e)) {
                  if ($best_kind ne "?") {
                    return ([$token],\@errors,$n_recursions);
                  }
                  else {
                    return ([$token],["e:undef_sym:0:-1:-2:-2:$token"],$n_recursions);
                  }
                }
          my $to_the_right = substr($e,length($token));
                if ($token eq "") {
                  # We've ruled out every possibility. We get here if the current token
                  # is ok, but the remainder of the expression gives errors. Since we've
                  # ruled out every possibility, we might as well resurrect the longest possibility.
                  $fatal_error = 1;
                  $cooked_token = $longest_ever;
                  if ($cooked_token =~ m/^(\s+).*/) {$cooked_token=" "}
                  $to_the_right = substr($e,length($longest_ever));
                }
                #if ($debug) {print "recursing, e=$e, token=$token=, e will be =".substr($e,length($token))."=\n"}
                my $recursion_ttl = $cooked_token; # The current token will be the one to the left when we recurse.
                if ($recursion_ttl eq " " and !$token_to_left=~m/^[\d\.]+$/) {
                  $recursion_ttl=$token_to_left;  # fix for bogus blank bug (see above)
                }
                my ($recursion_tokens_ref,$recursion_errors_ref,$nr) 
                     = lex(@save_args,EXPRESSION=>$to_the_right,TOKEN_TO_LEFT=>$recursion_ttl,
                                                RECURSING=>1,RECURSION_DEPTH=>$recursion_depth,N_RECURSIONS=>$n_recursions,
                                                UNITS_ALLOWED=>$units_allowed);
                $n_recursions = $nr;
                if ($n_recursions>=$max_recursions) {return([],[],$max_recursions+1)}
                #if ($debug) {my @recursion_errors = @$recursion_errors_ref;
                #        print "...back from recursing, # of errors=".$#recursion_errors."\n"}
                if (!@$recursion_errors_ref or $token eq "") {
                  push (@tokens,$cooked_token);
                  push (@tokens,@$recursion_tokens_ref);
                  push (@errors,@$recursion_errors_ref);
                  return (\@tokens,\@errors,$n_recursions);
                }
                # This possibility doesn't work. (If it had, we'd have returned in the code
                # above.) Strike it from the list, and try a shorter one.
                delete($possible{$best_kind});
        }
    #push(@tokens,$token);
    return (\@tokens,\@errors,$n_recursions); # If we exit here, we failed.
}

sub is_unit_group {
  my $e = shift;
  my $unit_group_pat = shift;
  my $units_pat = shift;
  if ($units_pat eq "") {return 0;}
  return ($e =~ m/^$unit_group_pat$/);
}

sub make_unit_group_pat {
  my $prefix_pat = shift;
  my $units_pat = shift;
  my $prefixable_units_pat = shift;

  # Note that in the following pattern, it makes a difference which order the two
  # options are in. I originally had units_pat first, and then "mm" got lexed as
  # "m","m".
  my $prefixed_unit_pat = "((($prefix_pat)($prefixable_units_pat))|($units_pat))";
  
  my $power_unit_pat = "$prefixed_unit_pat(\\-?\\d+(\\/\\d+)?)?";
  my $unit_group_pat = "((".$power_unit_pat.")[\\-\\.\\*\\/])*".$power_unit_pat;
}

sub contains_only_cons_and_vars {
  my $e = shift;
  my $cons_and_vars_pat = shift;
  my @list_em = ();
  my $s = $Spotter::sym_chars."0-9";
  #print "  s=$s, e=$e\n";
  while ($e =~ /([$s]+)/g) {
    if ($cons_and_vars_pat eq "") {return 0;}
    push @list_em,$1;
    #print "  --$1--\n";
  }
  foreach my $x (@list_em) {
    return 0 unless ($x =~ m/^($cons_and_vars_pat)$/);
  }
  return 1;
}

sub eliminate_illegal_characters {
  my $s = shift;
  my $replace_illegal_with = shift;
  my $legal_pat = "[$Spotter::legal_chars]";
  for (my $i=0; $i<length $s; $i++) {
    my $c = substr($s,$i,1);
    if (!($c =~ m/$legal_pat/)) {
      substr($s,$i,1) = $replace_illegal_with;
    }
  }
  return $s;
}

sub count_sig_figs {
  my $ee = shift;
  # The following is not meant to be totally airtight logic. E.g., it will give wrong answers on expressions
  # like "3.1 10^32+18". The main goal is not to give false positives, i.e., not to complain about an answer that actually is
  # fully evaluated with the right number of sig figs. In ambiguous cases, like 5300, return the lowest possible number of sig figs.
  my $mantissa = '__none__'; # the significant (without leading sign)
  $ee =~ s/\n$//; # trim trailing whitespace
  my $front = $ee;
  $front =~ s/\s*\*?\s*10\^[+\-]?\d+.*//; # strip off exponent and anything after it (no whitespace allowed)
  if ($ee=~/\^/ && $front=~/^[\-+]$/) {return 0} # special case for, e.g., +10^37, -10^37
  if ($front=~/^\s*$/) {$mantissa = ''} # e.g., numbers with no mantissa, just an exponent, e.g., 10^34
  if ($front=~/([\d]+)/) {$mantissa = $1}
  if ($front=~/([\d]*\.[\d]+)/) {$mantissa = $1}
  if ($front=~/([\d]+\.[\d]*)/) {$mantissa = $1}
  my $fully_evaluated = $mantissa ne '__none__'  && !($ee=~m@[a-zA-Z><%=~,!/{}\[\]\(\)]@);
  if ($fully_evaluated) {
    my $sig_figs = $mantissa;
    my $has_decimal_point = ($sig_figs=~/\./);
    $sig_figs =~ s/^0?\.0*//; # strip leading zeroes
    unless ($has_decimal_point) {$sig_figs =~ s/0+$//}; # strip zeroes that are ambiguous as to sig figs, e.g., 5300 -> 53, but leave 137.00 alone
    $sig_figs =~ s/\.//g; # strip decimal point
    # print "       ee='$ee', front='$front', mantissa='$mantissa', sf='$sig_figs'\n";
    return length($sig_figs);
  }
  else {
    return -1;
  }
}

1;
