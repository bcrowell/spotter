#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2001-2015 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
#
#----------------------------------------------------------------

use strict;

package InstructorInterface;
use base 'CGI::Application'; # makes me a subclass of this; similar to ISA
use CGI::Session;
use CGI::Application::Plugin::Authentication;

my $version_of_spotter = '3.0.3';
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

InstructorInterface->authen->config(
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
InstructorInterface->authen->protected_runmodes(qr/^(?!public_)/); # runmodes not starting with public_ are protected

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
  return run_interface($login,'public_roster',0,$session);
}

sub public_log_in {
  my $self = shift;
  my $login = Login->new('',0);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  return run_interface($login,'public_log_in',1,$session);
}

sub do_logged_in {
  my $self = shift;
  my $login = Login->new($self->authen->username,1);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  return run_interface($login,'do_logged_in',1,$session);
}

sub public_anonymous_use {
  my $self = shift;
  $self->authen->logout();
  my $login = Login->new('',0);
  $session = CGI::Session->new();
  $session->clear(); # they're anonymous, and we don't need to track them; but if the object was undef, we could
                     # get errors that would occur only for anonymous users, which would be hard to test for.
                     # We do a delete() at the end of run_interface.
  return run_interface($login,'public_anonymous_use',0,$session);
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
  return run_interface($login,'do_log_out',0,$session);
}

#========================================================================================================
# run_interface()
# Generates all the html output as its return value.
#========================================================================================================

sub run_interface {
  my $login = shift;
  my $run_mode = shift;
  my $need_cookies = shift;
  my $session = shift; # CGI::Session object, http://search.cpan.org/~markstos/CGI-Session-4.48/lib/CGI/Session.pm

  my $fatal_error = "";
  my $date_string = current_date_string_no_time();
  my $script_dir = Cwd::cwd();

  my $data_dir = data_dir();
  find_or_populate_data_dir($data_dir,$script_dir);

  $SpotterHTMLUtil::cgi = new CGI;
  my $out = ''; # accumulate all the html code to be printed out

  my $language;
  ($out,$fatal_error,$language) = get_language($out,$fatal_error); # for use in Tint; not currently implemented

  my $tree = tree();

  my ($basic_file_name,$xmlfile) = find_answer_file_and_set_up_log($data_dir);

  if (0 || Url::par_set("debug")) {SpotterHTMLUtil::activate_debugging_output()}
  #debugging_stuff($early_debug,$tree,$xmlfile,$login,$session,$run_mode); # gets saved up for later

  #($out,$fatal_error) = do_fiddle_with_account_settings($out,$fatal_error,$login,$tree);
  if ($tree->class_description()) {$out = $out .  $tree->class_description()."<br>\n"}
  #$out = show_functions($out,$tree,$login);
  $out = show_errors($out,$fatal_error,$tree,$login,$session,$xmlfile,$data_dir,$run_mode);

  $out = bottom_of_page($out,$tree); # date, debugging output, footer

  if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"done writing html output")}

  if ($run_mode eq 'do_log_out' || $run_mode eq 'public_anonymous_use') {$session->delete()}

  $session->flush();

  return $out; # all the html that has been accumulated above.

} # end of run_interface

sub show_errors {
  my ($out,$fatal_error,$tree,$login,$session,$xmlfile,$data_dir,$run_mode) = @_;
  if ($login->logged_in() && $tree->class_err()) { $out = $out .  "<p><b>Error: ".$tree->class_err()."</b></p>\n";  }
  ($out,$fatal_error) = do_function($out,$fatal_error,$tree,$login,$session,$xmlfile,$data_dir,$run_mode);
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


sub get_language {
  my ($out,$fatal_error) = @_;
  my $language = get_config("language");
  if (!defined $language) {$fatal_error = "Error reading configuration file config.json, or it didn't define language."}
  return ($out,$fatal_error,$language);
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
        do_a_problem($xmlfile,\$fatal_error,\$output,$data_dir,$tree,$login);
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
