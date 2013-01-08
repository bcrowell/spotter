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

package AnswerResponse;

use strict;

use Data::Dumper;
use Digest::SHA;

use Spotter;
use Expression;
use Parse;
use Eval;
use Rational;
use Units;
use Measurement;
use Debugging;

use Math::Complex;
use Math::Trig;
use Tint 'tint';

use utf8;

#----------------------------------------------------------------
# answer_response
#----------------------------------------------------------------
# The units are parsed by Units::parse_units(), which doesn't do much
# error checking. 
sub answer_response {
  my ($p,$ans,$units_allowed,$problem_label,$raw_input) = @_;
  # $problem_label is used as a unique label for the problem, caching results of calculations
  my $n_ans = $p->n_ans();
  my @vbl_list = $p->vbl_list();
  my %vbl_hash = $p->vbl_hash();
  my $n_vbl = $#vbl_list;
  my $result = "";
  my $internal_msg = "";

  my $debug = 0;

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"entered answer_response")}

  # Parse the units:
  for (my $i=0; $i<=$n_vbl; $i++) {
    my $vbl = $p->get_vbl($vbl_list[$i]);
    my $u = $vbl->units();
    if ($u) {
      $vbl->parsed_units(Units::parse_units(TEXT=>$u));
    }
    else {
      $vbl->parsed_units(Units->new());
    }
  }
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 100")}

  # Try to lex and parse the student's answer. This isn't actually terribly
  # useful, because inside the identical_answer() subroutine we need to
  # parse it all over again using the filter that goes with this canned
  # answer. However, we want to find out right away whether the student
  # made a syntax error.
  my $student_expression = Expression->new(EXPR=>$ans,OUTPUT_MODE=>"html",
					VAR_NAMES=>\@vbl_list,UNITS_ALLOWED=>$units_allowed);
  my $parse_error = $student_expression->has_errors(PARSE_IT=>1);
  if ($parse_error) {
    $result = $result . $student_expression->format_errors();
  }
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 200")}

  # In the following, the code for randomly generating values for the variables
  # is duplicated in identical_answer(). Should make this a method of the Problem object.
  if (!$parse_error) {
    my %meas_hash;
    if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 210")}
    for (my $j=0; $j<=$#vbl_list; $j++) {
      my $sym = $vbl_list[$j];
      my $var = $vbl_hash{$sym};
      my $x = rand_cplx($var->min(),$var->max(),$var->min_imag(),$var->max_imag());
      $meas_hash{$sym} = Measurement->new($x,$var->parsed_units());
      delete($Spotter::standard_cons_hash{$sym});
          	# ...this is obviously stupid, but I have to do it because I've implemented
          	# constants as globals rather than by parameter passing. Note that this won't
          	# have bad consequences later, because we only run with one set of symbols
          	# per invocation of the CGI.
    }
    if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 220")}
    $student_expression->vars_ref(\%meas_hash);
    my $result = $student_expression->evaluate();
    $parse_error = $student_expression->has_errors();
    if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 230")}
    if ($parse_error) {
      $result = $result . $student_expression->format_errors();
    }
    if (ref($result) ne "" && ref($result) ne "Math::Complex" && ref($result) ne "Measurement") {
      $parse_error = 1;
      $result = $result . ref($result)."=";
      $result = $result . "Illegal variable or use of units. Your expression doesn't result in a number.<br/>";
    }
  }

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response 300")}

  # Check whether it matches any of the right or wrong answers we know of.
  # what=1 : Check against the right answer.
  # what=2 : Check if it matches an anticipated wrong answer.
  my $student_answer_is_correct = 0;
  if (!$parse_error) {
    my $done = 0;
    my $fallback_result = "";
    for (my $what=1; $what<=2 && !$done; $what++) {
      for (my $i=0; $i<=$n_ans && !$done; $i++) {
        my $canned_ans = $p->get_ans($i);
        my $c = $canned_ans->is_correct();
        if (($what==1 && $c) || ($what==2 && !$c)) {
          if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response checking against canned answer ...")}
          my ($match,$msg,$temp_internal_msg) = identical_answer(STUDENT_ANSWER=>$ans,
            VARIABLES=>\%vbl_hash,CANNED_ANSWER=>$canned_ans,
            STUDENT_UNFILTERED_EX=>$student_expression,PROBLEM_LABEL=>$problem_label);
          if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"answer_response ...done")}
          if ($match eq "eq") {
            # It matches:
            $done = 1;
            if ($c) {
              my $sf = sig_figs_ok($canned_ans,$raw_input);
              # $result = $result . "<p>sig-fig check: $ans,$raw_input,".join(',',@$sf)."</p>";
              if ($sf->[0]) {
                $result = $result .  "<p>Correct</p>\n";
                $student_answer_is_correct = 1;
              }
              else {
                if ($sf->[1] eq 'not_evaluated') {
                  $result = $result .  
                   "<p>The numerical part of your answer, $raw_input, does not appear to have been completely evaluated. For instance, you could have entered 1/3 as your answer, when the correct answer would have been 0.3, 0.33, or something like that.\n"
                   ;
                }
                else {
                  my $ns = Parse::count_sig_figs($raw_input);
                  $result = $result .  "<p>".tint("responses.sig_fig_lecture",'raw_input'=>$raw_input)."</p>";
                }
                $result = $result . "</p>";
              }
            }
            else {
              $result = $result .  "<p>Incorrect. ".$canned_ans->response()."</p>\n";
            }
          }
          if ($match eq "er" && $c) {
            $fallback_result =   "<p>$msg</p>\n";
          }
          if ($match eq "un" && $c) {
            $fallback_result =    "<p>".tint("responses.units_lecture")."</p>\n";
          }
          if ($match eq "in" && $c) {
            $fallback_result =    "?"; # internal error
            $internal_msg = $temp_internal_msg;
          }
        }
      }
    }
    if ($result eq "") {$result = $fallback_result;}
    if ($result eq "") {$result = "<p>Incorrect</p>\n"}
    
    if ($result eq "?") {
      Log_file::write_entry(TEXT=>"internal error, $internal_msg");
      $result = "<p>Internal error.</p>\n";
    }
  }
  
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"leaving answer_response")}

  return ($result,$student_answer_is_correct);
}

#----------------------------------------------------------------
#           identical_answer
#----------------------------------------------------------------
sub sig_figs_ok {
  my ($canned,$student) = @_;
  my $range = $canned->sig_figs();
  if (! defined $range) {return [1,'not_specified']} # e.g., this is a symbolic problem, not a numerical one; or it's numerical, but no sig figs specified in xml file
  my $ns = Parse::count_sig_figs($student);
  if ($ns == -1) {return [0,'not_evaluated']}
  my ($min,$max);
  if ($range=~/^\d+$/) {
    $min = $range;
    $max = $range;
  }
  else {
    if ($range=~/^(\d+)-(\d+)$/) {
      ($min,$max) = ($1,$2);
    }
    else {
      return [1,'xml_error']; # error in xml syntax, so just say student is right
    }
  }
  return [($ns>=$min) && ($ns<=$max),'range',$ns,$min,$max];
}

#----------------------------------------------------------------
#           identical_answer
#
#           Test whether the student's answer is the same as the
#           canned one.
#----------------------------------------------------------------
# returns ($what,$message)
#   $what	   eq=matches
#              er=detected error in input
#              va=matches units, not value
#              un=doesn't match units
#              in=internal error
#   $message   relevant for what=2
#   $internal  in case of an internal error, this is what will end up in the log file
#----------------------------------------------------------------
# N_TESTS                how many random values of the variables to test; default is
#                        1 for analytic functions, 10 for nonanalytic
# STUDENT_ANSWER         a string
# CANNED_ANSWER          an Ans object
# VARIABLES              ref to a hash of Vbl objects
# STUDENT_UNFILTERED_EX  an Expression object; this is only used
#                        in order to generate the appropriate error message
#                        when there is an error evaluating (not parsing) 
#                        the student's expression
# PROBLEM_LABEL          a unique label for this problem, for use in caching results of calcs
#----------------------------------------------------------------
sub identical_answer {
  my $n_tests_if_analytic = 3; # With this set to 1, I got rare mess-ups, e.g., x was judged to be the same as asin(x), because x happened to be very small.
  my $n_tests_if_nonanalytic = 10;
  my %raw_args = (@_);
  my %args = (
    N_TESTS		=> $n_tests_if_analytic,
    VARIABLES	=> {},
    @_
  );
  my $overrode_n_tests_default = (exists $raw_args{N_TESTS});
  my $n_tests = $args{N_TESTS};
  my $vars_ref = $args{VARIABLES};
  my $canned_answer = $args{CANNED_ANSWER};
  my $their_string = $args{STUDENT_ANSWER};
  my $their_unfiltered_ex = $args{STUDENT_UNFILTERED_EX};
  my $problem_label = $args{PROBLEM_LABEL};
  my %vars = %$vars_ref;
  my @var_names = keys(%vars);
  my $internal_error = 0;
  my $internal_msg = "";
  my %flags = ();

  my $debug = 0;
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, 100")}

  # options for Data::Dumper, used with caching
	$Data::Dumper::Terse = 1;          # don't output names where feasible
	$Data::Dumper::Indent = 0;         # turn off all pretty print

  # Produce filtered versions of the two expressions:
    my $our_string = $canned_answer->e();
    my $filter = $canned_answer->filter();

    my $x = $filter;
    $x =~ s/\~/\($our_string\)/g;
    $our_string = $x;

    my $x = $filter;
    $x =~ s/\~/\($their_string\)/g;
    $their_string = $x;

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, 200")}
  # Parse their expression:
    my $their_expression = Expression->new(EXPR=>$their_string,OUTPUT_MODE=>"html",
					VAR_NAMES=>\@var_names);
    my $parse_error = $their_expression->has_errors(PARSE_IT=>1);
    if ($parse_error) {
      $internal_error = 1;
      my $err = $their_expression->format_errors();
      $internal_msg = "identical_answer(): error parsing student's expression $their_string, $err";
      # We already checked the student's input without putting it inside the filter
      # macro. An error at this point means an error in the filter, not in the student's input.
      # Or does it? Conceivably the filter could fail if, e.g., the student's input had
      # the wrong units. OK, but the solution to this is that I should check the units of
      # the student's expression before coming in here.
      # We /don't/ want to give the actual error message, because that reveals information
      # about the filter, and anyway the filter is just an internal thing.
    }

  my $cache_dir = 'data/cache'; # also in Spotter.cgi
  if (! -e $cache_dir) {mkdir($cache_dir)}
  my $cache_file_base = $cache_dir . '/' . $problem_label;

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, 300")}
  # Parse the canned expression:
    my $our_expression;
    if (!$internal_error) {
      # The first part of the filename will normally identify the problem uniquely. The hash at the end is
      # because we'll typically have more than one canned answer (some correct, some incorrect). Also, if
      # this answer in the answer file is changed, the hash will cause the new answer not to match the old one.
      my $cache_file_our_expression = $cache_file_base . '-our-' . substr(hash($our_string),0,8);
      my $parse_error;
      if (-e $cache_file_our_expression) {
        open(FILE,"<$cache_file_our_expression") or die "$!";
        $our_expression = eval <FILE>;
        close FILE;
        #SpotterHTMLUtil::debugging_output("identical_answer(): read parsed version of expression $our_string from cache");
      }
      else {
        $our_expression = Expression->new(EXPR=>$our_string,OUTPUT_MODE=>"html",
				  	VAR_NAMES=>\@var_names);
        $parse_error = $our_expression->has_errors(PARSE_IT=>1);
        open(FILE,">$cache_file_our_expression") or die "error: $!, opening $cache_file_our_expression for output";
        print FILE Dumper($our_expression);
        close FILE;
        #SpotterHTMLUtil::debugging_output("identical_answer(): wrote parsed version of expression $our_string to cache");
		  }
      if ($parse_error) {
        $internal_error = 1;
        $internal_msg = "identical_answer(): error parsing canned expression "
        		.$our_expression->expr()." errors=".$our_expression->format_errors();
      }
    }

  if ($Debugging::profiling) {
		my $aaa = $their_expression->is_nonanalytic();
		my $bbb = $our_expression->is_nonanalytic();
    Log_file::write_entry(TEXT=>"in identical answer, 400, their=$aaa=, our=$bbb=");
  }
  my $some_nonanalytic = 0;
  # Test for equality:
  if (!$overrode_n_tests_default) {
    if (@var_names) {
      if ($their_expression->is_nonanalytic() || $our_expression->is_nonanalytic()) {
        $n_tests = $n_tests_if_nonanalytic;
        $some_nonanalytic = 1;
	  	}
      else {
        $n_tests = $n_tests_if_analytic;
      }
    }
		else { # no variables, so no need to evaluate it more than once
      $n_tests = 1;
      # Note that we can have no variables, and yet be nonanalytic. This happens frequently
      # when the answer is purely numerical, but the filter is abs(~).
		}
  }
    my $disagreed = 0; # innocent until proven guilty
    if (!$internal_error) {
      my $hash_our_string = substr(hash($our_string),0,8);
      my $cache_file_inputs_base = $cache_file_base . '-inp-' . $hash_our_string .'-';
      my $cached = 1;
      # Normally if one of the cached input files exists, the rest will as well. However, if we increase $n_tests and then run Spotter again while
      # the old cache files exist, then goofy stuff happens (end up with cache file #1 and cache file #2 being duplicates). In this situation, it's better to regenerate
      # all the cache files every time. Therefore we check that all of them exist.
      for (my $i=1; $i<=$n_tests; $i++) {
        $cached = $cached && -e ( $cache_file_inputs_base . $i );
      }
      for (my $i=1; $i<=$n_tests && !$internal_error && !$disagreed; $i++) {
        my $cache_file_inputs = $cache_file_inputs_base . $i;
        if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, test $i")}
        my %meas_hash;
        my $unique = ''; # to help make sure we don't mistakenly use a cached output that doesn't correspond to the cached inputs
        if ($cached) {
          open(FILE,"<$cache_file_inputs") or die "$!";
          my $c = <FILE>;
          $unique = substr(hash($c),0,8);
          my $h = eval $c;
          %meas_hash = %$h;
          close FILE;
          #SpotterHTMLUtil::debugging_output("identical_answer(): read inputs from cache");
        }
        else {
          for (my $j=0; $j<=$#var_names; $j++) {
            my $sym = $var_names[$j];
            my $var = $vars{$sym};
            my $x;
            if ($some_nonanalytic && $i>1) {
              $x = rand_cplx($var->min(),$var->max(),$var->min_imag(),$var->max_imag());
            }
  					else {
              $x = rand_range($var->min(),$var->max());
					  }
            $meas_hash{$sym} = Measurement->new($x,$var->parsed_units());
          }
          my $c = Dumper(\%meas_hash);
          $unique = substr(hash($c),0,8);
          open(FILE,">$cache_file_inputs") or die "error: $!, opening $cache_file_inputs for output";
          print FILE $c;
          close FILE;
          #SpotterHTMLUtil::debugging_output("identical_answer(): wrote inputs to cache");
			  }
        $our_expression->vars_ref(\%meas_hash);
        $their_expression->vars_ref(\%meas_hash);
        if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, evaluating our result")}
        my $cache_file_output = $cache_file_base . '-out-' . $hash_our_string .'-' . $i . '-' . $unique;
        my $our_result;
        if ($cached && -e $cache_file_output) {
          open(FILE,"<$cache_file_output") or die "$!";
          $our_result = eval <FILE>;
          close FILE;
          SpotterHTMLUtil::debugging_output("identical_answer(): read output from cache");
        }
        else {
          $our_result = Measurement::promote_to_measurement($our_expression->evaluate());
          open(FILE,">$cache_file_output") or die "error: $!, opening $cache_file_output for output";
          print FILE Dumper($our_result);
          close FILE;
          SpotterHTMLUtil::debugging_output("identical_answer(): wrote output to cache");
				}
        if ($our_expression->has_errors()) {
          $internal_error = 1;
          $internal_msg = "identical_answer(): error parsing, filter=$filter, our_expression=".
          			$our_expression->expr().", our_result=$our_result, err=".
          			$our_expression->format_errors()."=".
          			$our_expression->{HAS_LEX_ERRORS}."=".
          			$our_expression->{HAS_PARSE_ERRORS}."=".
          			$our_expression->{HAS_EVAL_ERRORS}."=".
   					"<br/>";
        }
        else {
          if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, evaluating their result")}
          my $their_result = Measurement::promote_to_measurement($their_expression->evaluate());
          if ($their_expression->has_errors()) {
            $disagreed = 1;
            $flags{EVAL_ERROR} = 1;
          }
          else {
           if (!Measurement::compatible_units($their_result,$our_result,\%Spotter::standard_units)) {
             $disagreed = 1;
             $flags{UNITS_DISAGREE} = 1;
            }
            else {
              my $theirs_converted = Measurement::convert($their_result,$our_result,\%Spotter::standard_units);
              my $our_plain = $our_result;
              if (ref($our_plain) eq "Measurement") {$our_plain = $our_plain->number()}
              my $their_plain = $their_result;
              if (ref($their_plain) eq "Measurement") {$their_plain = $their_plain->number()}

              if ($canned_answer->tol_type() eq "mult" && $our_plain==0) {
                $disagreed = ($their_plain != 0);
              }
              if ($canned_answer->tol_type() eq "mult" && $our_plain!=0 && $their_plain==0) {
                $disagreed = 1;
              }
              if ($canned_answer->tol_type() eq "mult" && $our_plain!=0 && $their_plain!=0) {

                # Figure out the magnitude and argument of theirs/ours:
                  my $ratio = $theirs_converted/$our_result;
                  my $ratio_with_phase = Crunch::promote_cplx($ratio->number());
                  my $ratio_arg = Math::Complex::arg($ratio_with_phase);
                  my $ratio_mag = Math::Complex::abs($ratio_with_phase);

                # Figure out if ours is real:
                  my $ours_is_real = (ref($our_plain) eq "Complex" && Math::Complex::Im($our_result)==0)
                    || !ref($our_plain);

                # Figure out if theirs is real:
                  my $theirs_is_real = (ref($their_plain) eq "Complex" && Math::Complex::Im($their_plain)==0)
                    || !ref($their_plain);

                # Figure out if magnitudes disagree:
                  my $epsilon = $canned_answer->tol();
                  if ($ratio_arg>1) {$ratio_mag = 100000.}
                  if ($ratio_mag<1.) {$ratio_mag=1/$ratio_mag}
                  # The 1.0000001 here is so that, e.g., 2.5+-0.5 is guaranteed to include 3.0.
                  if ($ratio_mag>1+$epsilon*1.0000001) {
                    $disagreed = 1;
                  }

                # Even if the magnitudes agreed, we may have to do more:
                  if (!$disagreed) {
                    if ($ours_is_real && !$theirs_is_real) {
                      $disagreed = ($ratio_arg>$epsilon) || ($ratio_arg>0.00001);
                    }
                    if (!$ours_is_real && !$theirs_is_real) {
                      $disagreed = ($ratio_arg>$epsilon);
                    }
                  }

              }

              if ($canned_answer->tol_type() eq "add") {
                my $diff = $theirs_converted-$our_result;
                # The 1.0000001 here is so that, e.g., 2.5+-0.5 is guaranteed to include 3.0.
                if (abs($diff->number())>($canned_answer->tol())*1.0000001) {
                  $disagreed = 1;
                }
              }

              if ($disagreed) {
               $flags{NUMERICAL_DISAGREEMENT} = 1;
              }

            }
          }
        }
      }
   }
  
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"in identical answer, 500")}
  if ($internal_error) {Log_file::write_entry(TEXT=>$internal_msg); return ("in","",$internal_msg)}
  if (!$disagreed) {return ("eq","","")}
  my $msg = "";
  # Should improve the following so it passes on actual messages from the parser:
  if (exists($flags{EVAL_ERROR})) {return("er"," error evaluating","")}
  if (exists($flags{NUMERICAL_DISAGREEMENT})) {return("va","","")}
  if (exists($flags{UNITS_DISAGREE})) {return("un","","")}
}

sub rand_cplx {
  my ($min,$max,$min_imag,$max_imag) = @_;
  return rand_range($min,$max)+i*rand_range($min_imag,$max_imag);
}

sub rand_range {
  my ($min,$max) = @_;
  return rand(1)*($max-$min)+$min;
}

sub hash {
  my $string = shift;
  return Digest::SHA::sha1_hex($string);
}

1;
