use strict;

# Subs in this file are supposed to be pure functions. No side-effects, no dependence on
# global variables.

sub handle_mathematical_answer {
        my ($answer_param,$p,$login,$xmlfile,$hierarchy,$data_dir,$tree) = @_;
        my $output = '';
        my ($messages, $ans,$unit_list, $units_allowed,$vars) = poke_and_prod_student_answer($answer_param,$p);
        # SpotterHTMLUtil::debugging_output("in handle_mathematical_answer, ref(tree)=".ref($tree)."=");
        $output = $output . $messages;
        my ($query,$ip,$date_string,$throttle_dir,$when,$who,$query_sha1,
                            $exempt,$anon_forbidden,$forbidden_because_anon,$throttle_ok,$throttle_message,$problem_label) 
            = set_up_query_stuff($login,$p->description(),$xmlfile,$ans,$hierarchy,$data_dir);
        $output = $output . respond_to_query($ans,$throttle_ok,$p,$units_allowed,$problem_label,$login,$tree,$query,$throttle_dir,
                            $date_string,$ip,$who,$when,$query_sha1,$throttle_message,$unit_list,$vars,$answer_param);
        return $output;
}

sub poke_and_prod_student_answer {
        my ($raw_ans,$p) = @_;
        my $messages = '';

         # The following has to happen /before/ the sanity check, since the sanity check might
         # filter out illegal characters, like =. Therefore, we don't want to print out
         # any portion of the string, or it would be risky in terms of security.
         if (index($raw_ans,"=")>=0) {
           $raw_ans = substr($raw_ans,index($raw_ans,"=")+1);
           $messages = $messages . tint('checker.no_equals_sign_in_answers');
         }

        my ($ans,$insane) = SpotterHTMLUtil::sanity_check(TEXT=>$raw_ans);
        if ($insane) {$messages = $messages . "$insane";}

        # Make sure the raw version doesn't get used inadvertently later:
        undef $raw_ans;

        my $unit_list = "";
        my $units_allowed = 0; # not allowed by default; only allowed for numerical problems
        if ($p->options_stack_not_empty()) {
          $unit_list = $p->options_stack_top()->unit_list();
          $units_allowed = $p->options_stack_top()->units_allowed();
              # Currently there is no provision in the xml format to allow units_allowed to be set
              # in xml, and the r.h.s. of this assignment is always false.
              # If this is a numerical answer with a menu of units, the value of $units_allowed
              # gets modified below.
        }
        # The following is only for numerical answers that have units. If they entered 37 and selected units of meters
        # from the menu, what we do right here is parse the 37.
        if ($unit_list && $ans ne "") {
          $units_allowed = 1; # only for use by answer_response(), which gets the whole thing, like "37 m"
          my $unit_selection = $SpotterHTMLUtil::cgi->param("unit_list");
          my ($unit_selection,$insane) = SpotterHTMLUtil::sanity_check(TEXT=>$unit_selection);
          my $e = Expression->new(EXPR=>$ans,UNITS_ALLOWED=>0); # disallow units here, because we're only parsing the number
          my $m = Measurement::promote_to_measurement($e->evaluate());
          if ($e->has_errors()) {
            $messages = $messages . $e->format_errors();
            $ans = "";
          }
          if ($ans && !($m->reduces_to_unitless(\%Spotter::standard_units))) {
            $messages = $messages . tint('checker.do_not_type_units');
            $ans = "";
          }
          if ($ans ne "") {
            $m = $m * Measurement->new(1,Units::parse_units(TEXT=>$unit_selection));
            $ans = "$m";
          }
        }
        my @vbl_list = $p->vbl_list();
        return ($messages, $ans, $unit_list, $units_allowed,\@vbl_list);
}

sub respond_to_query {
        my ($ans,$throttle_ok,$p,$units_allowed,$problem_label,$login,$tree,$query,$throttle_dir,
                            $date_string,$ip,$who,$when,$query_sha1,$throttle_message,$unit_list,$vbl_list_ref,$raw_input) = @_;
        my $return = '';
        my @vbl_list = @$vbl_list_ref;
        my $is_symbolic = 0;
        if (@vbl_list) {$is_symbolic=1}
        my ($response,$student_answer_is_correct,$feedback);
        $feedback = '';
        $feedback = $feedback . $throttle_message unless $throttle_ok;
        if ($ans ne "" && $throttle_ok) {
          # The user gave an answer, and clicked the Check button.
          $feedback = $feedback . "<p>Your answer was $ans .</p>";
          ($response,$student_answer_is_correct) =  
               AnswerResponse::answer_response($p,$ans,$units_allowed,
                                               $problem_label,$raw_input);
          $feedback = $feedback . $response;
        }
        my $q = single_quotify_with_newlines($feedback);
        my $js_to_render_math = 'render_math(\'answer\',\'out\',new Array(\'' . join("','",@vbl_list) . '\'))';
        $return = $return .  "<script>$js_to_render_math</script>\n";
            # ... render the first time even if there's no keystroke, e.g, if the page was reloaded
            #     doesn't actually work ... why not?
        $return = $return .  "<script>var answer_feedback = $q;</script>\n".$SpotterHTMLUtil::cgi->startform."\n"; # see note in TODO
        $return = $return .  "<p>";
        my $default = "";
        my $confirm_recorded = 0;
        my $recording_err = '';
        if ($is_symbolic) {
            $default=$ans; # Display the old symbolic answer in the input box, so they can edit it easily. Don't do this for numerical answers (see above).
        }
        if ($ans ne "" && $throttle_ok) {
          if ($student_answer_is_correct) {
            $return = $return .  "Your correct answer was: ";
            if (!$is_symbolic) {
              $return = $return . $ans; # Display it above the input box, not in it, because it has units in it, and student shouldn't type in units.
            }
            $return = $return . '<br/>';
          }
          else {
            $return = $return .  "Try again:<br/>";
          }
          if ($login->logged_in()) {
            $recording_err = record_work(LOGIN=>$login,FILE_TREE=>$tree,ANSWER=>$ans,IS_CORRECT=>$student_answer_is_correct,
                     RESPONSE=>$response,DESCRIPTION=>$p->description(),QUERY=>$query);
            $confirm_recorded = $student_answer_is_correct && ($recording_err eq '');
          }
          write_throttle_file($throttle_dir,$date_string,$ip,$who,$when,$query_sha1);
        } 
        else {
          $return = $return .  "Answer:<br/>"
        }
        my $onkeyup = '';
        if ($is_symbolic) {$onkeyup = "onkeyup=\"$js_to_render_math\""}
        
        $return = $return .  <<JS;
            <input type="text" name="answer" id="answer" tabindex="1"  value="$default" size="60"  $onkeyup />
JS
        if ($unit_list) {
          my @unit_list = split (/\,/ , $unit_list);
          $return = $return .  $SpotterHTMLUtil::cgi->popup_menu(-name=>'unit_list',-values=>\@unit_list);
        }
        $return = $return .  $SpotterHTMLUtil::cgi->submit(-value=>"Check")."\n";
        $return = $return .  "</p>\n";
        $return = $return .  "\n".$SpotterHTMLUtil::cgi->endform."\n";
        if ($is_symbolic) {
          $return = $return .  tint('checker.explain_mathml');
        }

        my $recording_feedback = 'none';
        if ($confirm_recorded) {
           $return = $return .  "<p>This correct answer was recorded under your name, "
                .$tree->get_real_name($login->username(),"firstlast").".</p>\n";
           $recording_feedback = 'under_name';
        }
        if ($login->logged_in() && ($recording_err ne '') && $student_answer_is_correct) {
          $return = $return . "<p>The following error occurred when attempting to record your correct answer: $recording_err. ".
                              "Please report this error to your instructor, and make sure to record the date and time, what operating system and web browser you were ".
                              "using, and any other information that would help to reproduce the problem. ".
                              "</p>";
           $recording_feedback = 'error';
        }
        if (!($login->logged_in()) && $student_answer_is_correct) {
          $return = $return . "<p><font size='+4' color='red'><b>Your correct answer was not recorded under your name, because you are not logged in.</b></font></p>";
           $recording_feedback = 'not_logged_in';
        }
        if ($Debugging::recording_answers && $student_answer_is_correct) {
          Log_file::write_entry(TEXT=>
                     "Debugging::recording_answers, ".join(' ** ',($who,$ip,$recording_err,$query,$ans,$recording_feedback))
              );
        }
        $return = $return .  tint('checker.how_to_enter_answers');
        return $return;

}

sub set_up_query_stuff {
          my $login = shift;
          my $description = shift;
          my $xmlfile = shift;
          my $ans = shift;
          my $hierarchy = shift; # e.g. [ book chapter problem find  ]
          my $data_dir = shift;
          my ($query,$ip,$date_string,$throttle_dir,$when,$who,$query_sha1) = get_query_info($login,$description,$data_dir);
          my $exempt = file_exempt_from_throttling($xmlfile,$throttle_dir); # Grant exemptions to throttling for certain answer files, e.g., demo files.
          my $anon_forbidden = anon_forbidden_from_this_ip($ip,$throttle_dir); # Forbid anonymous use from certain addresses, e.g., your own school.
          my $forbidden_because_anon = ($anon_forbidden && $who eq '');
          my ($number,$longest_interval_violated,$when_over);
          my $throttle_ok = $ans eq '' || throttle_ok($throttle_dir,$date_string,$query_sha1,$who,$when,\$number,\$longest_interval_violated,\$when_over,$ip);
          my $reason_forbidden = '';
          my $exempt_message = '';
          if (!$throttle_ok) {
            $reason_forbidden = tint('checker.time_out',
                          'number'=>$number,'interval'=>$longest_interval_violated,'expire'=>$when_over);
            $exempt_message = tint('checker.exempt_from_time_out',
                          'number'=>$number,'interval'=>$longest_interval_violated);
            my $add_on = '';
            if ($who eq '') { $add_on = tint('checker.anonymous_time_out') }
            $reason_forbidden = "$reason_forbidden$add_on";
            $exempt_message = "$exempt_message$add_on";
            $exempt_message =~ s/\)\s+\(/ /g; # don't put two parenthetical statements in a row; combine them instead
          }
          if ($forbidden_because_anon) {
            $throttle_ok = 0;
            $reason_forbidden=tint('checker.anonymous_forbidden');
            $exempt_message=tint('checker.anonymous_forbidden_but_exempt');
          }
          my $throttle_message = '';
          if (!$throttle_ok) {
            if (!$exempt) {
              $throttle_message = "<p>$reason_forbidden</p>";
            }
            else {
              $throttle_message = "<p>$exempt_message</p>";
              $throttle_ok = 1;
            }
          }
          # generate $problem_label for caching, e.g., lm-2-5-7-1 for lm.xml, book 2, ...
          my @l = ();
          foreach my $l('file',@$hierarchy) {push @l,Url::par($l)}
          my $problem_label = join('-',@l);
          return ($query,$ip,$date_string,$throttle_dir,$when,$who,$query_sha1,
              $exempt,$anon_forbidden,$forbidden_because_anon,$throttle_ok,$throttle_message,$problem_label);
}

1;
