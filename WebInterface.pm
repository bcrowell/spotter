#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2001-2013 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
#
#----------------------------------------------------------------

use strict;

package WebInterface;
use base 'CGI::Application'; # makes me a subclass of this; similar to ISA
use CGI::Session;
use CGI::Application::Plugin::Authentication;

my $version_of_spotter = '3.0.4';
   # ... When I change this, I need to rename the subdirectory of spotter_js, e.g., from spotter_js/2.4.0 to spotter_js/2.4.1
   # ... and also change the number in Makefile
my $spotter_js_dir = "/spotter_js/$version_of_spotter";


use Spotter;
use Login;
use FileTree;
use Expression;
use Parse;
use Eval;
use Rational;
use Units;
use Measurement;
use Journal;
use WorkFile;
use BulletinBoard;
use Email;
use AnswerResponse;
use SpotterHTMLUtil;
require "Util.pm";
require "Throttle.pm";
use Debugging;
use Checker; # contains Options, Ans, Vbl, and Problem classes
require "CheckAnswer.pm";
use Url;
use Log_file;
use Tint 'tint';

use Math::Complex;
use Math::Trig;
use Message;
use Getopt::Std;
use XML::Parser;
use XML::Simple;
use CGI;
use Digest::SHA;
use POSIX (); # the () keeps it from importing a huge namespace
use Data::Dumper;
use Time::HiRes;
use File::stat;
use JSON;
use Cwd;

use utf8;

our $early_debug = '';

Url::decode_pars();
CGI::Session->name("sid");
our $session;

#========================================================================================================
# ---------- setup for CGI::Application::Plugin::Authentication ---------
#========================================================================================================

WebInterface->authen->config(
  DRIVER => [ 'Generic', sub {
    my ($username, $password) = @_;
    my $tree = tree();
    my $hashed = $tree->get_par_from_file($tree->student_info_file_name($username),'password');
    if (Login::hash(Login::salt().$password) eq $hashed) { return $username } else {return undef}
  } ],
  POST_LOGIN_RUNMODE => 'do_logged_in',
  LOGIN_RUNMODE => 'public_log_in',
  LOGOUT_RUNMODE => 'do_log_out',
  STORE => ['Cookie',
        NAME   => 'login',
        SECRET => 'not really so secret', # for my application, I don't care if they can forge a cookie
        EXPIRY => '+1d', # Not very relevant. If they're at home, presumably they're starting from the class's web page,
                        # so they have to log in every time. If they're at school and promiscuously sharing a browser,
                        # there's basically nothing I can do to prevent them from mistakenly putting in their answer
                        # while logged in as someone else.
    ],
);
WebInterface->authen->protected_runmodes(qr/^(?!public_)/); # runmodes not starting with public_ are protected

sub setup {
  my $self = shift;
  $early_debug = $early_debug . "login=form=".Url::par_is("login","form")."=\n";
  $early_debug = $early_debug . "login=".Url::par("login")."=\n";
  $early_debug = $early_debug . "self->authen->username=".($self->authen->username)."=\n";
  my $run_mode = 'public_anonymous_use';
  if (Url::par_is("login","form")) {
    if (Url::par_set("username")) {
      $run_mode = 'do_logged_in'; # can I cut this?
    }
    else {
      $run_mode = 'public_roster';
    }
  }
  else {
    if (($self->authen->username)=~/\w/) {
      $run_mode = 'do_logged_in';
    }
  }
  if (Url::par_is("login","log_out"))    { $run_mode = 'do_log_out' }
  if (Url::par_is("login","entered_password") && ! (($self->authen->username)=~/\w/)) { $run_mode = 'public_log_in'}
  $self->start_mode($run_mode);
  $self->run_modes([qw/
    public_anonymous_use
    public_roster
    public_log_in
    do_logged_in
    do_log_out
  /]);
  $self->mode_param('run_mode');
  # Use current path as template path,
  # i.e. the template is in the same directory as this script
  $self->tmpl_path('./');
}

sub data_dir {
  return 'data'; # relative to cwd, which is typically .../cgi-bin/spotter3
}

sub tree {
  my $data_dir = data_dir();
  return FileTree->new(DATA_DIR=>"${data_dir}/",CLASS=>Url::par("class"));
}

sub session_id {
  return Url::par('sid') if Url::par_set('sid');
  return $session->id if ref($session);
  return undef;
}

#========================================================================================================
# run modes
#========================================================================================================

sub public_roster {
  my $self = shift;
  my $login = Login->new('',0);
  $self->authen->logout();
  # This run mode is the one we're sent to by the class's web page.
  $session = CGI::Session->new() or die $session->errstr;
  $session->expire(3600); 
  $session->param('test','bluh');
  my $referer = CGI::referer(); # if they log out, send them back to the class's web page, which has the URL that gets
                                # them into spotter in the first place; this is helpful when students share a browser
  if ($referer =~ /Spotter\.cgi/) {  # not external
    if ($session->param('referer')) {
      $referer = $session->param('referer'); # may exist if someone else just logged out
    }
    else {
      $referer='';
    }
  }
  $session->param('referer',$referer);
  return run_spotter($login,'public_roster',0,$session);
}

sub public_log_in {
  my $self = shift;
  my $login = Login->new('',0);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  return run_spotter($login,'public_log_in',1,$session);
}

sub do_logged_in {
  my $self = shift;
  my $login = Login->new($self->authen->username,1);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  return run_spotter($login,'do_logged_in',1,$session);
}

sub public_anonymous_use {
  my $self = shift;
  $self->authen->logout();
  my $login = Login->new('',0);
  $session = CGI::Session->new();
  $session->clear(); # they're anonymous, and we don't need to track them; but if the object was undef, we could
                     # get errors that would occur only for anonymous users, which would be hard to test for.
                     # We do a delete() at the end of run_spotter.
  return run_spotter($login,'public_anonymous_use',0,$session);
}

# We don't keep them in spotter for anonymous use after they log out. This is because they may not realize they're
# not logged out, and get mad when their answers aren't recorded. Instead, we send them back to the referrer page.
sub do_log_out {
  my $self = shift;
  $self->authen->logout();
  my $login = Login->new('',0);
  # see notes in public_anonymous_use() for why we make session stuff even if they're not logged in
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  # Don't do ->clear(), because we want to keep the referer info so they can go back to class's web page.
  return run_spotter($login,'do_log_out',0,$session);
}

#========================================================================================================
# run_spotter()
# Generates all the html output as its return value.
#========================================================================================================

sub run_spotter {
  my $login = shift;
  my $run_mode = shift;
  my $need_cookies = shift;
  my $session = shift; # CGI::Session object, http://search.cpan.org/~markstos/CGI-Session-4.48/lib/CGI/Session.pm

  my $fatal_error = "";
  my $date_string = current_date_string_no_time();
  my $script_dir = Cwd::cwd();

  my $data_dir = data_dir();
  find_or_populate_data_dir($data_dir,$script_dir);

  shut_out_evil_ip("$data_dir/throttle",$date_string,$ENV{REMOTE_ADDR},\$early_debug);

  $SpotterHTMLUtil::cgi = new CGI;
  my $out = ''; # accumulate all the html code to be printed out

  my $language;
  ($out,$fatal_error,$language) = get_language($out,$fatal_error); # for use in Tint; not currently implemented

  my $tree = tree();

  my ($basic_file_name,$xmlfile) = find_answer_file_and_set_up_log($data_dir);

  my $current_problem;
  my $printed_any_problems_yet = 0;

  if (0 || Url::par_set("debug")) {SpotterHTMLUtil::activate_debugging_output()}
  renice_if_anonymous($login);
  my $cache_parsed_xml;
  ($out,$fatal_error,$cache_parsed_xml)
         = top_of_page($out,$fatal_error,$spotter_js_dir,$tree,$data_dir,$basic_file_name,$xmlfile,$need_cookies);
  debugging_stuff($early_debug,$tree,$xmlfile,$login,$session,$run_mode); # gets saved up for later

  ($out,$fatal_error) = do_fiddle_with_account_settings($out,$fatal_error,$login,$tree);
  if ($tree->class_description()) {$out = $out .  $tree->class_description()."<br>\n"}
  $out = show_messages($out,$tree,$login);
  $out = show_functions($out,$tree,$login);
  $out = show_errors($out,$fatal_error,$tree,$login,$session,$xmlfile,$cache_parsed_xml,$data_dir,$run_mode);

  if (Url::par_is("what","check")) {
    $out = $out .  toc_js_code(Url::param_hash()); # Fills in the <div> generated by toc_div(). See note in TODO.
  }

  $out = bottom_of_page($out,$tree); # date, debugging output, footer

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"done writing html output")}

  if ($run_mode eq 'do_log_out' || $run_mode eq 'public_anonymous_use') {$session->delete()}

  $session->flush();

  return $out; # all the html that has been accumulated above.

} # end of run_spotter

sub show_errors {
  my ($out,$fatal_error,$tree,$login,$session,$xmlfile,$cache_parsed_xml,$data_dir,$run_mode) = @_;
  if ($login->logged_in() && $tree->class_err()) { $out = $out .  "<p><b>Error: ".$tree->class_err()."</b></p>\n";  }
  ($out,$fatal_error) = do_function($out,$fatal_error,$tree,$login,$session,$xmlfile,$cache_parsed_xml,$data_dir,$run_mode);
  if ($fatal_error) {  $out = $out .  "<p>Error: $fatal_error</p>\n"; }
  return $out; 
}

sub debugging_stuff {
  my ($early_debug,$tree,$xmlfile,$login,$session,$run_mode) = @_;
  $early_debug =~ s/\n/<p>/g;
  SpotterHTMLUtil::debugging_output("early_debug=".$early_debug);
  SpotterHTMLUtil::debugging_output("The referrer is ".$session->param('referer'));
  SpotterHTMLUtil::debugging_output("The log file is ".Log_file::get_name());
  SpotterHTMLUtil::debugging_output("The xml file is ".$xmlfile);
  SpotterHTMLUtil::debugging_output("Logged in: ".$login->logged_in());
  SpotterHTMLUtil::debugging_output("Username: ".$login->username());
  SpotterHTMLUtil::debugging_output("run_mode: ".$run_mode);
  SpotterHTMLUtil::debugging_output("url::par(login): ".Url::par("login"));
  SpotterHTMLUtil::debugging_output("class_err=".$tree->class_err());
  SpotterHTMLUtil::debugging_output("class_description=".$tree->class_description());
  SpotterHTMLUtil::debugging_output("priority=".getpriority(0,0));
}

sub top_of_page {
  my ($out,$fatal_error,$spotter_js_dir,$tree,$data_dir,$basic_file_name,$xmlfile,$need_cookies) = @_;
  $out = $out .  SpotterHTMLUtil::HeaderHTML($spotter_js_dir)
              .  SpotterHTMLUtil::BannerHTML($tree)
              .  SpotterHTMLUtil::asciimath_js_code();
  my $cache_parsed_xml;
  ($out,$fatal_error,$cache_parsed_xml) = embedded_js($out,$fatal_error,$data_dir,$basic_file_name,$xmlfile,$need_cookies);
  return ($out,$fatal_error,$cache_parsed_xml);
}

sub bottom_of_page {
  my ($out,$tree) = @_;
  $out = $out .  "<p>time: ".current_date_string()." CST</p>\n";
  $out = $out .  SpotterHTMLUtil::accumulated_debugging_output();
  $out = $out .  SpotterHTMLUtil::FooterHTML($tree);
  return $out;
}

#----------------------------------------------------------------
# Cache a js version for use on the client side.
# optimization: use a simplified version of the xml file if that's all we need
#----------------------------------------------------------------
sub embedded_js {
  my ($out,$fatal_error,$data_dir,$basic_file_name,$xmlfile,$need_cookies) = @_;

  my $cache_dir = "$data_dir/cache"; # also in AnswerResponse
  my $js_cache = "$cache_dir/${basic_file_name}_js_cache.js";
  my $cache_parsed_xml = "$cache_dir/${basic_file_name}_parsed_xml.dump";
  #--- Write stuff to cache files, if cache files don't exist or are out of date:
  unless (-e $js_cache && modified($js_cache)>modified($xmlfile)) {
    my $return_status = jsify($xmlfile,$js_cache);
    if ($return_status->[0]>=2) {$out = $out .  "<p>".$return_status->[1]."</p>"}
  }
  #--------------
  if ($need_cookies) {
    $out = $out . tint('check_if_cookies_enabled');
    $out = $out . <<ALERT;
      <script type="text/javascript">
        if (!test_cookies_enabled()) {alert("You will not be able to log in, because cookies are disabled in your browser.");}
      </script>
ALERT
  }
  if (! -e $js_cache) {
    sleep 10; # maybe someone else is creating it right now
    if (! -e $js_cache) {$fatal_error = "file '$js_cache' does not exist, could not be created, and was not created by another process within 10 seconds"}
  }
  $out = $out .  "<script>\n".read_whole_file($js_cache)."\n</script>\n";
  return ($out,$fatal_error,$cache_parsed_xml);
}

sub get_language {
  my ($out,$fatal_error) = @_;
  my $language = get_config("language");
  if (!defined $language) {$fatal_error = "Error reading configuration file config.json, or it didn't define language."}
  return ($out,$fatal_error,$language);
}

sub renice_if_anonymous {
  my $login = shift;
  unless ($login->logged_in()) {
    renice_myself(17)
  }
  # Note that calls to nice() are cumulative.
  # It's not necessarily a good idea to do this any earlier in the program, because if we're going to terminate for some other reason,
  # it's better to get that done, and get the process off the system.
}

sub find_answer_file_and_set_up_log {
  my $data_dir = shift;
  my $basic_file_name = "spotter"; # default name of answer file
  if (Url::par_set("file")) {
    $basic_file_name = Url::par("file");
    $basic_file_name =~ s/[^\w\d_\-]//g; # don't allow ., because it risks allowing .. on a unix system
  }
  our $xmlfile = "answers/".$basic_file_name.".xml";
  if (-e $xmlfile) { # don't create foo.log if foo.xml doesn't exist
    Log_file::set_name($basic_file_name,"log",$data_dir); # has side effect of creating log file, if necessary
  }
  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"started")}
  return ($basic_file_name,$xmlfile);
}

sub find_or_populate_data_dir {
  my $data_dir = shift;
  my $script_dir = shift;
  if (!-e $data_dir) {die "The subdirectory '$data_dir' doesn't exist within the directory ${script_dir}. This should have been done by the makefile."}
  foreach my $data_subdir("cache","throttle","log") {
    my $d = "$data_dir/$data_subdir";
    if (!(-d $d)) {
      mkdir $d or die "Error creating directory $d, $!";
    }
  }
}

sub show_functions {
  my $out = shift; # append onto this
  my $tree = shift;
  my $login = shift;

  my $journals = $tree->journals();
  my $have_journals = defined $journals;
  if (!Url::par_is("login","form")) {
    if ($login->logged_in()) {
      my $have_workfile = -e ($tree->student_work_file_name($login->username()));
      $out = $out 
              . "<b>".$tree->get_real_name($login->username(),"firstlast")."</b> logged in "
              ." | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'check',DELETE=>'(login|journal|send_to)')."\">check</a>"
              ." | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'account',DELETE=>'(login|journal|send_to)')."\">account</a>"
              ." | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'grades', DELETE=>'(login|journal|send_to)')."\">grades</a>"
              ." | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'email',  DELETE=>'(login|journal|send_to)')."\">e-mail</a>";
      if ($have_journals) {
          $out = $out . 
               " | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'edit',DELETE=>'(login|journal|send_to)')."\">edit</a>";
        }
      if ($have_workfile) {
          $out = $out . 
               " | <a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'answers',DELETE=>'(login|journal|send_to)')."\">answers</a>";
      }
      $out = $out . 
               " | <a href=\"".Url::link(REPLACE=>'login',REPLACE_WITH=>'log_out',
                                            NOT_DELETE=>'',DELETE_ALL=>1)."\">log out</a><br>\n";
    }
  }

  if (Url::par_is("login","entered_password") && ! $login->logged_in()) {
    $out = $out . "<p><b>Error: incorrect password.</b></p>";
  }

  my (%journals,@journals_list);
  if ($have_journals) {
    my ($a,$b) = ($journals->[0],$journals->[1]);
    %journals = %$a;
    @journals_list = @$b;
  }
  if ($have_journals && Url::par_is("what","edit")) {
    my $first_one = 1;
    $out = $out .  "<p><b>edit</b> ";
    foreach my $j(@journals_list) {
      if (!$first_one) {$out = $out .  " | "}
      $first_one = 0;
      $out = $out . 
               "<a href=\"".Url::link(REPLACE=>'what',REPLACE_WITH=>'edit',DELETE=>'login',
                                            REPLACE2=>'journal',REPLACE_WITH2=>$j)."\">".$journals{$j}."</a>";
    }
    $out = $out .  "<p>\n";
  }

  return $out;
}

sub do_function {
  my $out = shift; # append onto this
  my $fatal_error = shift;
  my $tree = shift;
  my $login = shift;
  my $session = shift;
  my $xmlfile = shift;
  my $cache_parsed_xml = shift;
  my $data_dir = shift;
  my $run_mode = shift;

  if ($run_mode eq 'public_log_in' || $run_mode eq 'public_roster') {
    $out = $out .  do_login_form($tree);
  }

  if ($run_mode eq 'do_log_out' && $session->param('referer')) {
    $out = $out . "<p><a href=\"".$session->param('referer')."\">Click here to return to the class's web page.</a></p>"
  }

  if (!$fatal_error && !Url::par_is("login","form")) {
    $out = $out .  toc_div(); # Filled in by toc_js_code below.
    if (Url::par_is("what","check")) {
      # Seed the random number generator. We don't really want the numbers to
      # be random. We want the same random numbers to be used every time a particular
      # answer is checked. That way the comparison of input to stored answers is
      # deterministic. Since the CGI only ever checks one problem, this is guaranteed
      # to be deterministic as long as we always seed the random number generator
      # the same way. I was tempted to re-seed the generator every time through
      # answer_response(), but Perl doesn't allow srand to be called more than once,
      # and it doesn't matter because we only check one problem per run.
      srand(1);
      if (!(-e $xmlfile)) {$fatal_error = "file '$xmlfile' does not exist"}
      if (!(-r $xmlfile)) {$fatal_error = "unable to read file '$xmlfile'"} # This doesn't seem to work; see below.
      if (!$fatal_error && !(-e Log_file::get_name())) {$fatal_error = "unable to open log file '".Log_file::get_name()."'"}
      if (!$fatal_error && !(-w Log_file::get_name())) {$fatal_error = "unable to write to log file '".Log_file::get_name()."'"}
      if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"starting to parse the xml file")}
      if (Url::par_set("find")) {
        my $output;
        do_a_problem($xmlfile,$cache_parsed_xml,\$fatal_error,\$output,$data_dir,$tree,$login);
        if ($fatal_error ne '') {Log_file::write_entry(TEXT=>"fatal error from do_a_problem: $fatal_error")}
        $out = $out .  $output;
      }
    }
    if (Url::par_is("what","emailpassword")) {
      my $username = $SpotterHTMLUtil::cgi->param('username');
      my $id_given = $SpotterHTMLUtil::cgi->param('id');
      $id_given =~ s/^\@//; # get rid of initial @ sign in Fullerton College student ID
      my $id = $tree->get_student_par($username,'id');
      my $email = $tree->get_student_par($username,'email');
      my $bogus = '';
      if (! Email::syntactically_valid($email)) {$bogus = "You have not given a valid e-mail address, so you can't reset your password.";}
      if ($id_given ne $id) {$bogus = "Incorrect student ID.";}
      if ($bogus eq '') {
        srand();
        my $key = int(rand 1000).int(rand 1000).int(rand 1000);
        $tree->set_student_par($username,'newpasswordkey',$key);
        my $password = Login::hash(Login::salt().$id);
        $tree->set_student_par($username,'password',$password);
        Email::send_email(TO=>$email,SUBJECT=>'Spotter password',
             BODY=>("To reset your password, please go the following web address:\n".
                 Url::link(REPLACE=>'what',REPLACE_WITH=>'resetpassword',REPLACE2=>'username',REPLACE_WITH2=>$username,
                            REPLACE3=>'key',REPLACE_WITH3=>$key,RELATIVE=>0)));
        $out = $out .  "An e-mail has been sent to you with information on how to set a new password.<p>\n";
      }
      else { # We also end up here if the username is null or invalid.
        $out = $out .  "$bogus<p>\n";
      }
    }
    if (Url::par_is("what","resetpassword")) {
      my $username = Url::par('username');
      my $key = Url::par('key');
      my $key2 = $tree->get_student_par($username,'newpasswordkey');
      if ($key eq $key2 && $key2 ne '') {
        $tree->set_student_par($username,'state','notactivated');
        $tree->set_student_par($username,'newpasswordkey','');
        $out = $out .  "Your account has been inactivated, and you can now reactivate it by typing in your student ID and choosing ";
        $out = $out .  'a new password. <a href="'.Url::link(REPLACE=>'login',REPLACE_WITH=>'form',REPLACE2=>'what',REPLACE_WITH2=>'check',
                                           DELETE=>'key').'">';
        $out = $out .  "Click here</a> to reactivate your account.<p>\n";
      }
      else {
        $out = $out .  "Error: invalid key.<p>\n";
      }
    }

    if (Url::par_is("what","account")) {
      $out = $out .  do_account($login,$tree);
    }

    if (Url::par_is("what","email")) {
      my $bogus = '';
      my $own_email = '';
      my $username = '';
      if (!$login->logged_in()) {
        $bogus = "You must be logged in to send e-mail through Spotter.";
      }
      else {
        $username = $login->username();
        $own_email = $tree->get_student_par($username,'email');
        if ( ! Email::syntactically_valid($own_email)) {
          $bogus = "You can't send e-mail through Spotter because you haven't supplied a valid "
                  ."address yourself. To set your own address, click on the account link above.";
        }
      }
      if ($bogus eq '') {
        $out = $out .  do_email($username,$own_email,$tree);
      }
      else {
        $out = $out .  "<p>$bogus</p>\n";
      }
    }

    if (Url::par_is("what","grades")) {
      if ($login->logged_in()) {
        $out = $out .  do_grades($login,$tree);
      }
      else {
        $out = $out .  "You must be logged in to check your grade.<p>\n";
      }
    }

    if (Url::par_is("what","answers")) {
      if ($login->logged_in()) {
        $out = $out .  do_answers($login,$tree);
      }
      else {
        $out = $out .  "You must be logged in to look at your answers.<p>\n";
      }
    }

    if (Url::par_is("what","edit")) {
      my $which_journal = Url::par("journal");
      if ($which_journal ne '') {
        if ($login->logged_in()) {
          $out = $out .  do_edit_journal($which_journal,$login,$tree);
        }
        else {
          $out = $out .  "You must be logged in to edit.<p>\n";
        }
      }
    }

    if (Url::par_is("what","viewold")) {
      my $which_journal = Url::par("journal");
      if ($which_journal ne '') {
        if ($login->logged_in()) {
          $out = $out .  do_view_old($which_journal,$login,$tree);
        }
      }
    }
  } # end if (!$fatal_error && !Url::par_is("login","form"))

  return ($out,$fatal_error);
}

sub show_messages {
  my $out = shift; # append onto this
  my $tree = shift;
  my $login = shift;

  my $have_inbox = 0;
  my $have_unread_messages = 0;

  if ($login->logged_in()) {
    $have_inbox = $tree->student_inbox_exists($login->username());
    if ($have_inbox) {
      $have_unread_messages = BulletinBoard::has_unread_messages($tree,$login->username());
    }
  }

  if ($have_unread_messages) {
    my @message_keys = BulletinBoard::unread_message_keys($tree,$login->username()); # sort by date
    @message_keys = sort @message_keys;
    foreach my $key(@message_keys) {
      my $msg = BulletinBoard::get_message($tree,$login->username(),$key);
      if ($msg->[0] eq '') {
        $out = $out .  BulletinBoard::html_format_message($msg);
        my $date = BulletinBoard::current_date_for_message_key();
        BulletinBoard::mark_message_read($tree,$login->username(),$key,$date);
      }
    }
  }
  return $out;
}

#--------------------------------------------------------------------------------------------------

sub do_fiddle_with_account_settings {
  my ($out,$fatal_error,$login,$tree) = @_;
  if ($login->logged_in()) { 
    my $result = fiddle_with_account_settings($tree,$login->username());
    my $severity = $result->[0];
    my $message = $result->[1];
    if ($severity>=1) {
      if ($severity>=2) {
        $fatal_error = $message;
      }
      else {
        $out = $out . "<p>$message</p>";
      }
    }
  }
  return ($out,$fatal_error);
}

# We come here if the user is logged in. If necessary, we handle stuff here like changing their password or email.
# Returns [0,''] normally, or [severity,error message] otherwise.
# A severity >=2 means not to treat them as logged in.
sub fiddle_with_account_settings {
  my $tree = shift;
  my $username = shift;
  if ($SpotterHTMLUtil::cgi->param('email') ne '') {
    $tree->set_par_in_file($tree->student_info_file_name($username),'email',$SpotterHTMLUtil::cgi->param('email'));
    $tree->set_par_in_file($tree->student_info_file_name($username),'emailpublic',
                                                         ($SpotterHTMLUtil::cgi->param('emailpublic') eq 'public'));
  }
  if ($SpotterHTMLUtil::cgi->param('newpassword1') ne '') {
    my ($p1,$p2) = ($SpotterHTMLUtil::cgi->param('newpassword1'),$SpotterHTMLUtil::cgi->param('newpassword2'));
    if ($p1 ne $p2) {
      return [2,tint('user.not_same_password_twice')];
    }
    if ($p1 eq '' && $tree->get_student_par($username,'state') eq 'notactivated') {
      return [2,tint('user.blank_password')];
    }
    if ($p1 ne '') {
      my $password = $p1;
      $tree->set_par_in_file($tree->student_info_file_name($username),'state','normal');
      $tree->set_par_in_file($tree->student_info_file_name($username),'password',
                          Login::hash(Login::salt().$password));
    }
  } # end if setting new password
  return [0,''];
}

#========================================================================================================
#========================================================================================================
sub do_a_problem {
  my ($xmlfile,$cache_parsed_xml,$fatal_err_ref,$output_ref,$data_dir,$tree,$login) = @_;
  my $err = '';
  my $xml_data = get_xml_tree($xmlfile,$cache_parsed_xml,\$err);
  if ($err ne '') {
    $$fatal_err_ref = $err;
    $$output_ref = '';
  }
  else {
    my ($output_early,$output_middle,$output_late);
    my %params = Url::param_hash();
    my $err = do_answer_check($xml_data,\$output_early,\$output_middle,\$output_late,\%params,$login,$xmlfile,$data_dir,$tree);
    if ($err ne '') {$$fatal_err_ref = $err}
    $$output_ref = $output_early.$output_middle.$output_late;
    if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"done parsing the xml file")}
  }
}

sub js_stuff {
}

# This generates the <div> in which the TOC is painted.
# It can come either before or after toc_js_code().
sub toc_div {
  return <<JS;
    <div id="check_ui_div"></div>
JS
}

# This generates the code for painting the TOC.
# It can come either before or after toc_div.
sub toc_js_code {
  my %param_hash = @_;
  my $js_cgi_params = hash_to_js('[a-z]+',Url::param_hash());
  return <<JS;
    <script>var cgi_params = $js_cgi_params;</script>
    <script src="$spotter_js_dir/checker_ui.js"></script>
JS
}

#========================

sub get_xml_tree {
  my ($xmlfile,$cache_parsed_xml,$err_ref) = @_;
  $$err_ref = '';
  my $xml_data;
  unless (-e $cache_parsed_xml && modified($cache_parsed_xml)>modified($xmlfile)) {
    $xml_data = eval{XML::Simple::XMLin($xmlfile,ForceArray =>['toc_level','toc','problem','find','ans','var'])};
    if ($@) { my $err = "error parsing $xmlfile, $@"; Log_file::write_entry(TEXT=>$err); $$err_ref=$err; return undef}
    if (open(FILE,">$cache_parsed_xml")) {
      print FILE Dumper($xml_data);
      close FILE;
    }
    else {
      Log_file::write_entry(TEXT=>"error writing to $cache_parsed_xml, $!"); # soft error, someone else may be writing it
    }
  }
  else {
    if (open(FILE,"<$cache_parsed_xml")) {
      local $/;
      my $VAR1;
      eval(<FILE>);
      $xml_data = $VAR1;
      close FILE;
    }
    else {
      my $err = "error opening $cache_parsed_xml for input, $!"; # if it exists but we can't read it, there's a misconfiguration
      $$err_ref = $err;
      Log_file::write_entry(TEXT=>$err);
    }
  }
  return $xml_data;
}



sub do_edit_journal {
  my $journal = shift;
  my $login = shift;
  my $username = $login->username();
  my $tree = shift;
  my ($text,$is_locked) = $tree->read_journal($username,$journal);
  my $edited_version = $SpotterHTMLUtil::cgi->param('journalText');
  if ($edited_version || $SpotterHTMLUtil::cgi->param('submitJournalButton')) { # The second clause allows users to submit an empty journal.
    if (!$is_locked) {
      $text = $edited_version;
      $text =~ s/\015?\012/\n/g;
      # Break up long lines:
      for (my $i=1; $i<=30; $i++) {
        $text =~ s/\n([^=*][^\n]{80,}) (\w[^\n]{80,})/\n$1\n$2/g;
      }
      $text =~ s/\n/\012/g;
      if (!($text=~m/\n$/)) {$text = "$text\n"}
      $tree->write_journal($username,$journal,$text);
    }
  }
  my $old = '';
  my $diffs_dir = $tree->diffs_directory();
  my $journal_diffs_dir = "$diffs_dir/$username/$journal";
  if (-e $diffs_dir) {
    my @diffs = sort <$journal_diffs_dir/*>;
    if (@diffs) {
      my $n = @diffs;
      $n--;
      my $url = Url::link(REPLACE=>'what',REPLACE_WITH=>'viewold',DELETE=>'login',REPLACE2=>'journal',REPLACE_WITH2=>$journal);
      $old = tint('journal.old_versions_form','n'=>$n,'url'=>$url);
    }
  }
  return tint('journal.edit_page',
    'cooked_text'=>Journal::format_journal_as_html($text),
    'form'=>($is_locked ? tint('journal.is_locked') : tint('journal.edit_text_form','url_link'=>Url::link(),'text'=>$text) ),
    'old'=>$old
  );
}



sub do_view_old {
  my $journal = shift;
  my $version = $SpotterHTMLUtil::cgi->param('version');
  my $login = shift;
  my $tree = shift;
  my $username = $login->username();
  my $out = '';
  $out = $out . "<h2>Viewing old version $version of $journal</h2>\n";
  my $diffs_dir = $tree->diffs_directory();
  my $journal_diffs_dir = "$diffs_dir/$username/$journal";
  my @diffs = sort <$journal_diffs_dir/*>;
  # create empty file:
  my $rebuild = "$journal_diffs_dir/rebuild";
  open(FILE,">$rebuild");
  close(FILE);
  for (my $i=0; $i<=$version-1; $i++) {
    system("patch -s $rebuild $diffs[$i]");
  }
  unlink "$rebuild.orig";
  local $/;
  open(FILE,"<$rebuild");
  my $text = <FILE>;
  close FILE;
  $out = $out . "<pre>$text</pre>";
  return $out;
}

sub do_answers {
  my $login = shift;
  my $tree = shift;
  my $out = '';
  my ($err,$answers) = WorkFile::list_all_correct_answers_for_one_student($tree,$login->username());
  if ($err eq '') {
    my @answers = @$answers;
    $out = $out .  tint('checker.explain_answer_list');
    foreach my $answer(@answers) {
      $out = $out .  "$answer<br/>\n";
    }
  }
  else {
    $out = $out .  "<p>Error: $err</p>\n";
  }
  return $out;
}

sub do_grades {
  my $login = shift;
  my $tree = shift;
  local $/; # slurp the whole file
  my $out = '';
  my $err = 0;
  my $username = $login->username();
  my $filename = $tree->grade_report_file_name($username);
  open(REPORT,"<$filename") or $err=1;
  if ($err) {$out = $out . "Error opening grade report.<p>\n"; return}
  $out = $out . <REPORT>;
  close REPORT;
  return $out;
}

sub do_email {
      my $username = shift;
      my $own_email = shift;
      my $tree = shift;

      my $out = '';

      if (Url::par_set("send_to")) {
        my $own_name = $tree->get_real_name($username,"firstlast");
        my $subject1 = "Email via Spotter";
        if ($tree->class_description()) {$subject1 = $tree->class_description()}
        my $subject2 = $SpotterHTMLUtil::cgi->param('emailSubject');
        my $link = Url::link();
        my $body = $SpotterHTMLUtil::cgi->param('emailBody');
        $out = $out . Email::send_email_from_student($username,$own_email,$own_name,Url::par("send_to"),$link,$body,
               $subject1,$subject2);
        return $out;
      }

      my @roster = $tree->get_roster();
      $out = $out . tint('checker.explain_email_privacy');
      $out = $out . "<table>\n";
      my $instructor_emails = $tree->instructor_emails();
      my @instructors = keys %$instructor_emails;
      if (@instructors) {
        my $form = "instructors";
        if (@instructors==1) {$form = "instructor"}
        $out = $out . "<tr><td><i>$form</i></td></tr>\n";
      }
      foreach my $who(@instructors) {
        my $email = $instructor_emails->{$who};
        $out = $out . "<tr>";
        $out = $out . "<td>$who</td>\n<td>";
        if ($email ne '') {
          $out = $out . link_to_send_email($email);
        }
        else {
          $out = $out . '---';
        }
        $out = $out . "</td></tr>\n";
        
      }
      $out = $out . "<tr><td><i>students</i></td></tr>\n";
      foreach my $who(@roster) {
        $out = $out . "<tr>";
        $out = $out . "<td>".$tree->get_real_name($who,"lastfirst")."</td>\n<td>";
        if (Email::syntactically_valid($tree->get_student_par($who,"email")) && $tree->get_student_par($who,"emailpublic")) {
          my $email = $tree->get_student_par($who,"email");
          $out = $out . link_to_send_email($email);
        }
        else {
          if (!Email::syntactically_valid($tree->get_student_par($who,"email"))) {
            $out = $out . '---'; # no (syntactically valid) address given
          }
          else {
            $out = $out . '(not public)'; # address given, but not public
          }
        }
        $out = $out . "</td></tr>\n";
      }
      $out = $out . "</table>\n";
      return $out;
}

sub link_to_send_email {
  my $address = shift;
  return " <a href=\""
     .Url::link(REPLACE=>'what',REPLACE_WITH=>'email',  DELETE=>'(login|journal)',REPLACE2=>'send_to',REPLACE_WITH2=>$address)
     ."\">Send e-mail.</a>";

}

sub do_account {
  my $login = shift;
  my $tree = shift;
  my $email = $tree->get_student_par($login->username(),'email');
  my $emailpublic = $tree->get_student_par($login->username(),'emailpublic');
  my $url = Url::link(REPLACE2=>'what',REPLACE_WITH2=>'check');
  return tint('checker.your_account_form','url'=>$url,'email'=>$email,'emailpublic'=>($emailpublic ? 'checked' : ''));
}

sub do_login_form {
  my $tree = shift;
  my $step = 1;
  my $username = '';
  my $disabled = 0;
  my $state = '';
  my $out = '';
  if (Url::par_set("class") && !$tree->class_err()) {
    $step = 2;
    $username = Url::par('username');
    $disabled = ($tree->get_student_par($username,'disabled'));
    $state = ($tree->get_student_par($username,'state'));
    SpotterHTMLUtil::debugging_output("student's account has state=".$state);
    if ($username) {$step=3}
  }
  if ($disabled) {
    $out = $out . "Your account has been disabled.<p>\n";
  }
  else {
    if ($step==1) { # set class
      $out = $out . "To log in, start from the link provided on your instructor's web page.<p>\n";
      # has to have &class=bcrowell/f2002/205 or whatever in the link
    }
    if ($step==2) { # set username
      my @roster = $tree->get_roster();
      $out = $out . "<p><b>Click on your name below:</b><br>\n";
      foreach my $who(sort {$tree->get_real_name($a,"lastfirst") cmp $tree->get_real_name($b,"lastfirst")} @roster) {
        $out = $out . '<a href="'.Url::link(REPLACE=>'username',REPLACE_WITH=>$who).'">';
        $out = $out . $tree->get_real_name($who,"lastfirst");
        $out = $out . "</a><br>\n";
      }
    }
    if ($step==3) { # enter password, and, if necessary, activate account
      $out = $out . "<b>".$tree->get_real_name($username,"firstlast")."</b><br>\n";
      my $date = current_date_string();
      $out = $out . tint('user.password_form',
        'url'=>Url::link(REPLACE=>'login',REPLACE_WITH=>'entered_password'),
        'username'=>$username,
        'prompt'=>($state eq 'normal' ? ' Password:' : ' Student ID:'), # initially, password is student ID
        'activation'=>($state eq 'notactivated' ? tint('user.activate_account') : ''),
        'real_name'=>$tree->get_real_name($username,"firstlast"),
        'not_me_url'=>Url::link(DELETE=>'username')
      );
      if ($state eq 'normal') { # offer them a chance to recover their password; don't do if state isn't normal, because
                                # then they haven't even set a password yet
        $out = $out . tint('user.forgot_password',
          'url'=>Url::link(DELETE=>'login',REPLACE=>'what',REPLACE_WITH=>'emailpassword',DELETE=>'login'),
          'username'=>$username
        )
      }
    }
  }
  return $out;
}

#----------------------------------------------------------------
# descend the XML tree, collect the data we need, and construct the response to the student's answer
#----------------------------------------------------------------

# This routine is written assuming that the cgi query params in $params_ref are sufficient to specify an actual problem we're going to check.
sub do_answer_check {
  my ($xml,               # ref returned by XML::Simple, holds the whole XML file as a tree
      $output_early_ref,
      $output_middle_ref,
      $output_late_ref,
      $params_ref,
      $login,
      $xmlfile,
      $data_dir,
      $tree
      )
         = @_;
  my %params = %$params_ref;
  my @output = ('','','');
  my ($title,
      @hierarchy,   # e.g., book chapter problem find  
      @number_style,
      %labels);
  my $err = get_general_info_from_xml($xml,\$title,\@hierarchy,\%labels,\@number_style);
  return $err if $err ne '';

  my $tocs = $xml->{'toc'}; # ref to an array of all the top-level tocs in the file
  if (defined $tocs) {
    my $deepest = @hierarchy-1;
    for (my $i=0; $i<=$deepest-2; $i++) {
      my $tag = 'toc';
      my $want_number = $params{$hierarchy[$i]};
      my $next = undef;
      foreach my $toc(@$tocs) { # search for the one with the right number; $toc is a hashref like {num=>,toc=>}
        $next = $toc if $toc->{'num'} eq $want_number;
      }
      return "problem not found, no number $want_number at level $hierarchy[$i]" if ! defined $next;
      if ($i<$deepest-2) {$tocs = $next->{'toc'}} else {$tocs=$next}
    }
  }
  else {
    $tocs = $xml;
  }
  # find the problem
  my $problems = $tocs->{'problem'}; # ref to hash of problems
  my $want_number = $params{'problem'};
  my $l = undef;
  return "expected hash ref, not found" unless ref($problems)=='HASH';
  foreach my $label(keys %$problems) {
    if ($labels{$label} eq $want_number) {$l=$label; last}
  }
  return "problem number $want_number not found" if ! defined $l;
  # we're down to the 'problem' level, so now find the 'find'
  my %stuff = (); # a hash of arrays; e.g., {unit_list=>'m/s',var=>[{'sym'=>'x','units'=>'m'},{'sym'=>'t','units'=>'s'}],content=>'the speed',ans=>[{e=>'x/t'}]
  my $type = 'expression';
  $type = $problems->{$l}->{'type'} if exists $problems->{$l}->{'type'};
  my $success = get_problem_from_tree($problems->{$l},$params{'find'},\%stuff);
  return "failed to find problem $params{problem}, part $params{find}" unless $success;
  my $content = $stuff{'content'};
  return "no text for problem" unless defined $content;
  my $unit_list = $stuff{'unit_list'}; #
  if (! defined $unit_list) {$unit_list = []}
  if (!ref($unit_list) && $unit_list eq '') {$unit_list = []}
  if (!ref($unit_list) && $unit_list ne '') {$unit_list = [$unit_list]}
  my $var_list = $stuff{'var'};
  if (! defined $var_list) {$var_list = []}
  my $ans_list = $stuff{'ans'};

  my $p = Problem->new();
  $p->type($type);
  $p->description($content);
  foreach my $var(@$var_list) {
    my $v = Vbl->new($var->{'sym'});
    $v->units($var->{'units'}) if exists $var->{'units'};
    $v->min($var->{'min'}) if exists $var->{'min'};
    $v->max($var->{'max'}) if exists $var->{'max'};
    $p->add_vbl($v);
  }
  foreach my $ans(@$ans_list) {
    foreach my $thing('filter','tol_type','tol','sig_figs') {
      $ans->{$thing} = {'filter'=>'~','tol_type'=>'mult','tol'=>.00001,'sig_figs'=>undef}->{$thing} unless exists $ans->{$thing};
    }
    my $a = Ans->new($ans->{'e'},$ans->{'filter'},$ans->{'tol'},$ans->{'tol_type'},$ans->{'sig_figs'});
    $a->response($ans->{'content'}) if exists $ans->{'content'};
    $p->add_ans($a);
  }
  if (@$unit_list>0) {
    $p->options_stack_top()->unit_list($unit_list->[-1]);
  }

  if ($p->type eq 'expression') {
    my $a = $SpotterHTMLUtil::cgi->param("answer");
    $output[1] = $output[1] . handle_mathematical_answer($a,$p,$login,$xmlfile,\@hierarchy,$data_dir,$tree);
  }
  else {
    $output[0] = $output[0] . generate_js_for_data_element($stuff{'data'});
    my ($a,$b,$c)= handle_nonmathematical_answer($p);
    $output[0] = $output[0] . $a;
    $output[1] = $output[1] . $b;
    $output[2] = $output[2] . $c;
  }



  $$output_early_ref  = $output[0];
  $$output_middle_ref = $output[1];
  $$output_late_ref   = $output[2];

  return '';
}


sub get_problem_from_tree {
  my ($tree,$find,$stuff_ref) = @_;
  my $descend;
  $descend = sub {
    my ($tree,$stuff) = @_;
    push @$stuff,{};

    my $depth = @$stuff;

    my $debug = sub { };

    &$debug("in descend, depth=$depth");

    if (ref($tree) ne 'ARRAY' && ref($tree) ne 'HASH') {&$debug('not array or hash??'); return 0 }
    if (ref($tree) eq 'ARRAY') {
      &$debug('array');
      foreach my $e(@$tree) {
        if (&$descend($e,$stuff)) {return 1; &$debug('array, success')} else {pop @$stuff;}
      }
      &$debug('array, failure'); return 0;
    }
    if (ref($tree) eq 'HASH') {
      &$debug('hash');
      if (exists $tree->{'ans'}) {$stuff->[-1]->{'ans'} = $tree->{'ans'}}
      if (exists $tree->{'var'}) {$stuff->[-1]->{'var'} = $tree->{'var'}}
      if (exists $tree->{'data'}) {$stuff->[-1]->{'data'} = $tree->{'data'}}
      if (exists $tree->{'content'}) {$stuff->[-1]->{'content'} = $tree->{'content'}} # shouldn't actually need this, handled on client side
      if (exists $tree->{'options'}) {
        if (&$descend($tree->{'options'},$stuff)) {&$debug('hash, options, success'); return 1}
      }
      if (exists $tree->{'find'}) {
        if (exists $tree->{'find'}->{$find}) {
          if (exists $tree->{'unit_list'}) {$stuff->[-1]->{'unit_list'}=$tree->{'unit_list'}}
          if (&$descend($tree->{'find'}->{$find},$stuff)) {&$debug('hash, success'); return 1} else {&$debug('hash, failure deeper'); pop @$stuff; return 0}
        }
        else {
          &$debug("hash, find $find not found"); pop @$stuff; return 0;
        }
      }
      else {
        &$debug('hash, collected some stuff'); return 1;
      }
    }
    return 0;
  };
  my @stuff = ();
  my $success = &$descend($tree,\@stuff);
  if (!$success) {return 0}
  # change array of hashes into hash of arrays
  my %h = ();
  foreach my $crud(@stuff) {
    foreach my $what(keys %$crud) {
      $h{$what} = [] unless exists $h{$what};
      my $a = $h{$what};
      push @$a,$crud->{$what};
    }
  }
  # var and ans come back as unnecessarily nested arrays, [[...]]
  # xml dtd and the way xml::simple work probably guarantee that the outer one is single element
  if (exists $h{'var'}) {my $u=$h{'var'}; $h{'var'}=$h{'var'}->[-1]}
  if (exists $h{'ans'}) {my $u=$h{'ans'}; $h{'ans'}=$h{'ans'}->[-1]}
  # unit_list and content should be one-element arrays, so dereference them, too
  # really should check for error if more than one element (indicates illegal/impossible nesting)
  if (exists $h{'unit_list'}) {$h{'unit_list'}=$h{'unit_list'}->[-1]}
  if (exists $h{'content'}) {$h{'content'}=$h{'content'}->[-1]}
  if (exists $h{'data'}) {$h{'data'}=$h{'data'}->[-1]}
  %$stuff_ref = %h;
  return 1;
}

sub get_general_info_from_xml {
  my ($xml,$title_ref,$hierarchy_ref,$labels_ref,$number_style_ref) = @_;
  foreach my $el('num','log_file') {
    return "xml has no $el elements" unless exists $xml->{$el};
  }
  my $title = $xml->{'title'};
  $title = '' if ! defined $title;
  my @hierarchy;
  my @number_style;
  my %labels;

  my $el_toc_levels = $xml->{'toc_level'}; # array ref
  if (defined $el_toc_levels) {
    if (ref($el_toc_levels) ne 'ARRAY') {$el_toc_levels = [$el_toc_levels]}
    foreach my $level(@$el_toc_levels) {
      my $n = $level->{'level'};
      my $type = $level->{'type'};
      my $number_style = $level->{'number_style'};
      $hierarchy[$n] = $type;
      $number_style[$n] = $number_style;
    }
  }
  else {
    @hierarchy = ();
  }
  @hierarchy = (@hierarchy,'problem','find');

  my $el_nums = $xml->{'num'}; # hash ref

  # Normally, el_nums looks like this:
  #   { 'swimbladder' => { 'label' => '2' }, 'copter' => { 'label' => '4' }}
  # but because XML::Simple is psychotic, it can look like this if there's only one problem in the file:
  #   { 'id' => 'ohm', 'label' => '1' }
  # Detect the second case and rework it to look like the first:
  if (exists $el_nums->{'id'} && ! ref $el_nums->{'id'}) {$el_nums = {($el_nums->{'id'})=>{'label'=>$el_nums->{'label'}}}}

  # And now, finally, analyze it:
  foreach my $label(keys %$el_nums) {
    my $n = $el_nums->{$label}->{'label'};
    $n=$n+0 if $n=~/^\d+$/; # make sure it's represented as a number -- is this necessary?
    $labels{$label} = $n;
  }

  $$title_ref = $title;
  @$hierarchy_ref = @hierarchy;
  %$labels_ref = %labels;
  @$number_style_ref = @number_style;

  return '';
}

sub generate_js_for_data_element {
      my $list = shift; # array ref
      my $output = '';
      $list = [$list] if ref($list) ne 'ARRAY';
      foreach my $data(@$list) {
        my $content = SpotterHTMLUtil::super_and_sub($data->{'content'});
        if (exists $data->{'var'}) {
          $content =~ s/'/\\'/g;
          $output = $output . "<script>\nvar $data->{var}=\'$content\';\n</script>";
        }
        if (exists $data->{'array'}) {
          $content =~ s/\n/ /g;
          $output = $output . "<script>\nvar $data->{array}=new Array($content);\n</script>";
        }
      }
      return $output;
}

sub handle_nonmathematical_answer {
        my $p = shift;
        my @output = ('','','');
        my $t = $p->type;
        my $description = $p->description;
        my $query = $ENV{'QUERY_STRING'}; # the following lines are duplicated elsewhere in the code
        $query =~ s/username=[^\&]*\&?//;
        $query =~ s/what=check\&?//;
        $query =~ s/'/\\'/g; # so it can go inside '' in javascript
        $description =~ s/{/</g;         
        $description =~ s/}/>/g;         
        my $dd = $description;
        $dd =~ s/'/\\'/g; # so it can go inside '' in javascript
        $dd =~ s/\n/ /g;  # ditto
        $output[1] = $output[1] . <<HTML;
          <script src="$spotter_js_dir/ajax.js"></script>
          <script src="$spotter_js_dir/login.js"></script>
          <script src="$spotter_js_dir/$t.js"></script>
HTML
        # The following is a lame kludge used in order to get this stuff printed out later, not right away.
        $output[2] = $output[2] . <<HTML;
          <div id="instructions"></div>
          <div id="container"></div>
          <script>
          var login = get_login_info();
          var user = login[0];
          var query = '$query';
          // var description = '$dd';
          populate($t);
          </script>
          <div id="footnote"></div>
          <script>if (typeof(footnote) == 'string') {document.getElementById("footnote").innerHTML=footnote}</script>
HTML
       return @output;
}


sub get_query_info {
          my $login = shift;
          my $description = shift;
          my $data_dir = shift;

          my $debug = 0;

          my $query = $ENV{'QUERY_STRING'};
          my $ip = $ENV{REMOTE_ADDR};
          my $date_string = current_date_string_no_time();
          my $throttle_dir = "$data_dir/throttle";
          if (! -e $throttle_dir) {mkdir($throttle_dir)}
          my $when = time;
          my $who = '';
          if ($login->logged_in()) {$who = $login->username()}
          my $query_sha1 = Digest::SHA::sha1_base64($description); 
          return ($query,$ip,$date_string,$throttle_dir,$when,$who,$query_sha1);
}

sub file_exempt_from_throttling {
            my $xmlfile = shift;
            my $throttle_dir = shift;
            my $exempt = 0;
            if (open(FILE,"<$throttle_dir/exempt_files")) { # lines should be like foo.xml
            while (my $line=<FILE>) {
              chomp $line;
              if ("answers/$line" eq $xmlfile) {$exempt=1}
            }  
            close(FILE);
          }
          SpotterHTMLUtil::debugging_output("file_exempt_from_throttling=$exempt");
          return $exempt;
}

sub anon_forbidden_from_this_ip {
  my $ip = shift;
  my $throttle_dir = shift;
  my $anon_forbidden = 0;
  if (open(FILE,"<$throttle_dir/forbid_anonymous_use_at")) {
    while (my $line=<FILE>) {
      chomp $line;
      my @a = split /\./,$ip;
      my @b = split /\./,$line;
      my $match = 1;
      for (my $i=0; $i<=$#b; $i++) {
        if ($a[$i] != $b[$i]) {$match=0}
      }
      if ($match && $#b>=0) {$anon_forbidden=1}
    }  
    close(FILE);
  }
  return $anon_forbidden;
}

# returns '' normally, error otherwise
sub record_work {
  my %args = (
    ANSWER=>'',
    DESCRIPTION=>'',
    LOGIN=>'',
    FILE_TREE=>'',
    IS_CORRECT=>'',
    RESPONSE=>'',
    QUERY=>'',
    @_,
  );
  my $record_response = "";
  if (!$args{IS_CORRECT}) {
    $record_response = $args{RESPONSE};
    $record_response =~ s/\n/ /g;
    $record_response =~ s/^\<p\>//;
    if (length($record_response)>64) {$record_response=substr($record_response,0,64)}
  }
  my $description = $args{DESCRIPTION};
  $description =~ s/\n/ /g;
  $description =~ s/^\s+//;
  if (length($description)>64) {$description=substr($description,0,64)}
  my $answer = $args{ANSWER};
  $answer =~ s/\n/ /g;
  my $login = $args{LOGIN};
  my $tree = $args{FILE_TREE};
  my $is_correct = 0;
  if ($args{IS_CORRECT}) {$is_correct=1}
  if (! ref($tree)) {return 'Programming error in record_work'}
  my $file = $tree->student_work_file_name($login->username());
  if ($file eq '') {return 'Error finding student work file, probably because class= was not set in the url that pointed to Spotter'}
  my $query = $args{QUERY}; # the following 4 lines are duplicated elsewhere in the code
  $query =~ s/username=[^\&]*\&?//;
  $query =~ s/sid=[^\&]*\&?//;
  $query =~ s/class=[^\&]*\&?//;
  $query =~ s/what=check\&?//;
  $query =~ s/amp=\&?//;
  open(FILE,">>$file") or return "error opening work file";
  my $nlines = 6;
  if ($record_response) {
    $nlines = $nlines+1;
  }
  my $ip = $ENV{REMOTE_ADDR};
  print FILE "answer,$nlines\n";
  print FILE "  query:       $query\n";
  print FILE "  description: $description\n";
  print FILE "  answer:      $answer\n";
  print FILE "  correct:     $is_correct\n";
  print FILE "  date:        ".current_date_string()."\n";
  print FILE "  ip:          $ip\n";
  if ($record_response) {
    print FILE "  response:    $record_response\n";
  }
  close(FILE);
  return '';
}

# Shift as much work onto the user's CPU as possible. Write JS code that has lots of data
# from the answer file (but not the answers themselves).
# Returns [severity,error], where severity=0 means normal, 1 means soft error, 2 means error that should be reported.
sub jsify {
  my $xmlfile = shift;
  my $js_cache = shift;

  my $return_value = [0,''];

  my $parser = new XML::Parser(ErrorContext => 2);

  unless (open(JS,">$js_cache")) {
    SpotterHTMLUtil::debugging_output("failed, $!"); 
    return [1,"error opening $js_cache for output"]; # soft error since, e.g., some other process may currently be updating it
  }

  my %num = ();
  my $head = {'type'=>undef,'contents'=>[],'parent'=>undef,'title'=>undef,'num'=>undef}; 
                    # the head of the toc tree
                    # each node in the tree is a hash containing these keys:
                    #   type : says what it is, e.g., 'chapter' if it's a chapter; can also be undef if it's the root of the tree, or 'problem' or 'find'
                    #   contents : ref to a list of nodes it contains, or, if level is 'find', ref to a data structure about that problem
                    #   parent : ref to the parent node
                    #   title
                    #   num
  my $current_toc = $head;

  my @options = ();
  my @vars = ();
  my $in_find = 0;
  my $in_var = 0;
  my $deep_in_find = 0;
  my $depth = 0;
  my $file_title = '';
  my $hier_depth = 0;
  my @hierarchy = ();
  my @number_style = ();

  $parser->setHandlers(
    Char=>sub {
      my ($p,$data) = @_;
      # In the following two lines, it's ok if the preexisting string is an undef; append_xml_char_data handles that.
      if ($in_find and $deep_in_find==0) {$current_toc->{'title'} = append_xml_char_data($current_toc->{'title'},$data)}
      if ($in_var) {$vars[$depth-1]->[-1]->{'description'} = append_xml_char_data($vars[$depth-1]->[-1]->{'description'},$data)}
    },
    Start=>sub {
      my $p = shift;
      my $el = shift;
      my %attrs = @_;
      ++$depth;
      if ($el eq 'spotter') {$file_title=$attrs{'title'}}
      if ($el eq 'find') {$in_find = 1}
      if ($el ne 'find' && $in_find) {++$deep_in_find}
      if ($el eq 'num') {
	my $id = $attrs{'id'}; # symbolic name
	my $label = $attrs{'label'}; # number
        $num{$id} = $label;
      }
      if ($el eq 'options') {
        $options[$depth] = \%attrs;
      }
      if ($el eq 'var') {
        # associate a <var> with the level that surrounds it (typically associated with a <find>), because we never actually go inside a <var> tag, except to set its description
        if (! exists $vars[$depth-1]) {$vars[$depth-1]=[]}
        my $l = $vars[$depth-1];
        push @$l,\%attrs;
        $in_var = 1;
      }
      if ($el eq 'toc_level') {
        my $level = $attrs{'level'};
        my $number_style = $attrs{'number_style'};
        $number_style[$level] = single_quotify($number_style);
      }
      if ($el eq 'toc' or $el eq 'problem' or $el eq 'find') {
        my $contents_ref = $current_toc->{'contents'};
        my ($type,$title,$num);
        if ($el eq 'toc') {$type = $attrs{'type'}; $title=$attrs{'title'}; $num=$attrs{'num'}}
        if ($el eq 'problem') {$type = 'problem'; $title=''; $num=$num{$attrs{'id'}}}
        if ($el eq 'find') {$type = 'find'; $title=''; $num=$attrs{'id'}}
        $current_toc = {'type'=>$type,'contents'=>[],'parent'=>$current_toc,'title'=>$title,'num'=>$num,'options'=>'null','vars'=>'null'};
        push @$contents_ref,$current_toc;
        $hierarchy[$hier_depth++] = single_quotify($type);
      }
    },
    End=>sub {
      my ($p,$el) = @_;
      if ($el eq 'var') {$in_var = 0} # vars can't be nested
      if ($el eq 'find') {$in_find = 0} # finds can't be nested
      if ($el ne 'find' && $in_find) {--$deep_in_find}
      if ($el eq 'find') {
        # accumulate options from all surrounding levels:
        my %o = ();
        for (my $i=0; $i<=$depth; $i++) {%o=hashref_union_to_hash(\%o,$options[$i])} # It's okay if $options[i] is undef.
        $current_toc->{'options'} = hash_to_js('unit_list',%o);
        # accumulate vars from all surrounding levels:
        my @v = ();
        for (my $i=0; $i<=$depth; $i++) {if (defined $vars[$i]) {my $u=$vars[$i]; @v=(@v,@$u)}} 
        my @z;
        foreach my $v(@v) {push @z,hash_to_js('',%$v)}
        $current_toc->{'vars'} = '['.join(',',@z).']';
      }
      if ($el eq 'toc' or $el eq 'problem' or $el eq 'find') {
        $current_toc = $current_toc->{'parent'};
        --$hier_depth;
      }
      --$depth;
      # shorten arrays, by setting last valid index:
      $#options = $depth;
      $#vars = $depth;     
    },
  );

  -e $xmlfile or return [1,"file $xmlfile not found"]; # happens if they're just using it for grade reports, not answer checking
  $parser->parsefile($xmlfile);

  print JS <<STUFF;
    function Toc(type,parent,num,options,vars,title) {
      this.type = type;
      this.parent = parent;
      this.num = num;
      this.contents = new Array(0);
      this.options = options;
      this.vars = vars;
      this.title = title;
      if (parent!=null) {parent.contents[num] = this;}
    }
STUFF
  print JS "var hier = [".join(',',@hierarchy)."];\n";
  print JS "var number_style = [".join(',',@number_style)."];\n";

  my $did_head = 0;
  my @toc;
  my $do_toc;
  $do_toc = sub {
    my $toc = shift;
    my $pushed = 0;
    if ((!defined $toc->{'num'}) and defined $toc->{'title'}) {
      Log_file::write_entry(TEXT=>"error in jsify, no number defined in toc for a child of ".join('_',@toc)."; look in javascript generated in html for 'error here'");
      $return_value = [2,"Error parsing XML file, see log."];
      print JS "// error here\n";
    }
    if (defined $toc->{'num'} and defined $toc->{'title'}) {
      my $num = $toc->{'num'};
      my $title = $toc->{'title'};
      my $type = $toc->{'type'};
      my $parent = 'toc'.join('_',@toc);
      push @toc,$num;
      $pushed = 1;
      my $options = $toc->{'options'};
      my $vars = $toc->{'vars'};
      my $qtitle = single_quotify($title);
      my $qtype = single_quotify($type);
      print JS "toc".join('_',@toc)." = new Toc($qtype,$parent,\"$num\",$options,$vars,$qtitle);\n"
    }
    else {
      if (!$did_head) {
        my $q = single_quotify($file_title);
        print JS "toc = new Toc(null,null,null,null,null,$q);\n";
        $did_head = 1;
      }
      else {
        Log_file::write_entry(TEXT=>"error in jsify, would have overwritten head of toc, possibly because no number defined in toc for a child of ".join('_',@toc)
                                      ."; look in javascript generated in html for 'error here'");
        $return_value = [2, "Error parsing XML file, see log."];
      print JS "// error here\n";
      }
    }
    my $contents = $toc->{'contents'};
    foreach my $c(@$contents) {
      &$do_toc($c,$depth+1);
    }
    pop @toc if $pushed;
  };
  &$do_toc($head);
  close JS;
  return $return_value;
}
