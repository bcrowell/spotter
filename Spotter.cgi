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
#
#----------------------------------------------------------------

use strict;

my $version_of_spotter = '3.0.0'; # When I change this, I need to rename the subdirectory of spotter_js, e.g., from spotter_js/2.4.0 to spotter_js/2.4.1
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
use SpotterText;
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

print run_spotter();

#========================================================================================================
# A nasty, brutish, and long subroutine that generates all the html output as its return value.
#========================================================================================================

sub run_spotter {

my $data_dir = 'data'; # relative to cwd, which is typically .../cgi-bin/spotter3
my $script_dir = Cwd::cwd();

if (!-e $data_dir) {die "The subdirectory '$data_dir' doesn't exist within the directory ${script_dir}. This should have been done by the makefile."}
foreach my $data_subdir("cache","throttle","log") {
  my $d = "$data_dir/$data_subdir";
  if (!(-d $d)) {
    mkdir $d or die "Error creating directory $d, $!";
  }
}


#----------------------------------------------------------------
# Fighting against DOS attacks, spambots, etc.:
#----------------------------------------------------------------
# The file dos_log contains the following:
#    ip address of most recent user
#    list of all the times that that user has used Spotter
# The file blocked_<date> contains a list of ip addresses that are blocked for the day.
# If being attacked systematically, can set apache's httpd.conf file to deny access to
# an ip address or a range of ip addresses; see http://httpd.apache.org/docs/2.0/howto/auth.html .
# Basically you put something like "Deny from 85.91" at the end of the 'Directory "/usr/local/www/cgi-bin"' section.
# The apache mechanism is effective against a range of IP addresses, whereas the stuff built into Spotter
# below only works against an attack from a single address.

# The following is not really necessary, since it's better to do it from within the apache config file,
# but it can't hurt, and this mechanism may be useful, e.g., for people who don't have permission to
# alter their apache config files:
my $ip = $ENV{REMOTE_ADDR};
if ($ip=~m/^85\.91/) {exit(0)} # 85.91 was the source of a DOS attack against me, in 2006

my $date_string = current_date_string_no_time();
my $throttle_dir = "$data_dir/throttle";
my $blocked_file_name = "$throttle_dir/blocked_$date_string";
my $dos_log = "$throttle_dir/dos_log";
my $ip = $ENV{REMOTE_ADDR};
my $time_window = 60; # seconds
my $max_accesses = 60; 
   # maximum of this many accesses within time window; note that multiple users behind the same router/hub can appear as the same ip;
   # I found empirically that setting $max_accesses to 20 and $time_window to 60 caused my own students to be blocked on the first
   # day of class when they were all initializing their accounts from behind the same router.
my $accesses_to_sleep = 10; # If this many, then delay response by $sleep_time, so real users won't be likely to get blacklisted.
my $sleep_time = 10; # seconds
my $now = time;
if (open(FILE,"<$blocked_file_name")) {
  while (my $line=<FILE>) {
    if ($line=~m/$ip/) {exit(0)}
  }
  close(FILE);
}
my $last_ip = '';
if (open(FILE,"<$dos_log")) {
  my $line = <FILE>;
  chomp $line;
  $last_ip = $line;
  close(FILE);
}
if ($ip eq $last_ip) {
  if (open(FILE,">>$dos_log")) {
    print FILE "$now\n";
    close(FILE);
  }
  if (open(FILE,"<$dos_log")) {
    my $line = <FILE>;
    chomp $line; # skip ip, which we already know
    my $accesses = 0;
    while (my $t=<FILE>) {
      chomp $t;
      ++$accesses if ($now-$t<$time_window);
    }
    close(FILE);
    if ($accesses>$max_accesses && !($ip =~ /^207\.233/)) { # 207.233 is Fullerton College
      if (open(FILE,">>$blocked_file_name")) { # This ip isn't already in there, or we would have quit earlier.
        print FILE "$ip\n";
        close(FILE);
      }
    }
    if ($accesses>$accesses_to_sleep) {sleep $sleep_time}
  }
} # end if same as last ip
else { # not the same as last ip
  if (open(FILE,">$dos_log")) {
    print FILE "$ip\n$now\n";
    close(FILE);
  }
} # end if not same as last ip

#----------------------------------------------------------------
# Initialization
#----------------------------------------------------------------
$SpotterHTMLUtil::cgi = new CGI;
my $out = ''; # accumulate all the html code to be printed out
Url::decode_pars();

my $tree = FileTree->new(DATA_DIR=>"${data_dir}/",CLASS=>Url::par("class"));

#----------- subroutine for checking passwords
sub my_password_checker {
       my $login = shift;
       if (!$tree->class()) {$login->login_error("No such class."); return 0}
       my ($err,$password_hash) = $tree->get_par_from_file($tree->student_info_file_name($login->username()),"password");
       if ($err) {$login->login_error("No such user, $err."); return 0}
       if (!$login->check_password($password_hash)) {$login->login_error("Incorrect password.");return 0}
       return 1;
}

our $basic_file_name = "spotter"; # default name of answer file
if (Url::par_set("file")) {
  $basic_file_name = Url::par("file");
  $basic_file_name =~ s/[^\w\d_\-]//g; # don't allow ., because it risks allowing .. on a unix system
}

#----------------------------------------------------------------
# Find the XML file.
#----------------------------------------------------------------
our $xmlfile = "answers/".$basic_file_name.".xml";

if (-e $xmlfile) { # don't create foo.log if foo.xml doesn't exist
  Log_file::set_name($basic_file_name,"log",$data_dir); # has side effect of creating log file, if necessary
}

if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"started")}

my $current_problem;
my $printed_any_problems_yet = 0;

if (Url::par_set("debug")) {SpotterHTMLUtil::activate_debugging_output()}

#------------ initialize some login information --------------
our $login = Login->new(
   CGI=>$SpotterHTMLUtil::cgi,
   COOKIE_NAME=>'spotter_login',
   HASH_STRING=>'spotter',
   PASSWORD_CHECKER=>\&my_password_checker
);

#------------ lower priority for anonymous users ----------------------
unless ($login->logged_in()) {
  renice_myself(17)
}
  # Note that calls to nice() are cumulative.
  # It's not necessarily a good idea to do this any earlier in the program, because if we're going to terminate for some other reason,
  # it's better to get that done, and get the process off the system.

#----------------------------------------------------------------
# Contents of page.
#----------------------------------------------------------------

#----------------------------------------------------------------
# Before we write the headers, we need to check whether to set or
# delete a cookie.
#----------------------------------------------------------------
  my $cookie_list = [];
  my $delete_cookie = Url::par_is("login","form"); # can also get set in a couple of other places below
  if (Url::par_is("login","set_cookie")) {
    # The cookie is being set, but isn't set yet, so the normal
    # thing where we read the cookie to check if we're logged in doesn't work.
    # Calling cookie_value() below has the side-effect of
    # setting login->auth.
    my $password = $SpotterHTMLUtil::cgi->param('password');
    $login->username($SpotterHTMLUtil::cgi->param('username'));
    $login->date($SpotterHTMLUtil::cgi->param('date'));
    my $cookie_value = $login->cookie_value($password);
    $login->logged_in(my_password_checker($login));
    if (!$login->logged_in() && $password =~ m/^\@(\d+)$/) {
      # Fullerton College IDs have an extra @ on the front. Don't choke if they type in the @ sign.
      $password = $1;
      $login->login_error('');
      $cookie_value = $login->cookie_value($password);
      $login->logged_in(my_password_checker($login));
      if ($Debugging::recording_answers && !$login->logged_in()) {Log_file::write_entry(TEXT=>"Debugging::recording_answers, login failed, ".$login->username())}
    }
    if ($login->logged_in()) {
      if ($SpotterHTMLUtil::cgi->param('email') ne '') {
        $tree->set_par_in_file($tree->student_info_file_name($login->username()),'email',$SpotterHTMLUtil::cgi->param('email'));
        $tree->set_par_in_file($tree->student_info_file_name($login->username()),'emailpublic',
                                                             ($SpotterHTMLUtil::cgi->param('emailpublic') eq 'public'));
      }
      if ($SpotterHTMLUtil::cgi->param('newpassword1') ne '') {
        my ($p1,$p2) = ($SpotterHTMLUtil::cgi->param('newpassword1'),$SpotterHTMLUtil::cgi->param('newpassword2'));
        if ($p1 ne $p2) {
          $login->login_error("You didn't type the same password twice. Please use the back button in your browser and try again.");
          $login->logged_in(0);
        }
        if ($p1 eq '' && $tree->get_student_par($login->username(),'state') eq 'notactivated') {
          $login->login_error("You didn't enter a password. Please use the back button in your browser and try again.");
          $login->logged_in(0);
        }
        if ($login->logged_in() && $p1 ne '') {
          $password = $p1;
          $cookie_value = $login->cookie_value($password);
          $tree->set_par_in_file($tree->student_info_file_name($login->username()),'state','normal');
          $tree->set_par_in_file($tree->student_info_file_name($login->username()),'password',
                              Login::hash($login->hash_string().$password));
        }
      } # end if setting new password
      my $cookie = $SpotterHTMLUtil::cgi->cookie(-name=>$login->cookie_name(),-value=>$cookie_value);
      # By default, cookie expires when the browser exits.
      my @foo = ($cookie);
      $cookie_list = \@foo;
      if ($Debugging::recording_answers) {Log_file::write_entry(TEXT=>"Debugging::recording_answers, logging in, ".$login->username())}
    } # end if $login->logged_in()
    else {
      $delete_cookie = 1;
    }
  } # end if (Url::par_is("login","set_cookie")) {
  if (Url::par_is("login","log_out")) {
    $delete_cookie = 1;
    $login->logged_in(0);
    if ($Debugging::recording_answers) {Log_file::write_entry(TEXT=>"Debugging::recording_answers, logging out, ".$login->username())}
  }
  if ($delete_cookie) {
      my $cookie_deletion = $SpotterHTMLUtil::cgi->cookie(-name=>$login->cookie_name(),-value=>'',-expires=>'-1y');
      my @foo = ($cookie_deletion);
      $cookie_list = \@foo;
    }

#----------------------------------------------------------------
# Headers.
#----------------------------------------------------------------
$out = $out .  SpotterHTMLUtil::HTTPHeader($cookie_list);
$out = $out .  SpotterHTMLUtil::HeaderHTML($spotter_js_dir);

#----------------------------------------------------------------
# Cache a js version for use on the client side.
#----------------------------------------------------------------
# optimization: use a simplified version of the xml file if that's all we need
my $cache_dir = "$data_dir/cache"; # also in AnswerResponse
my $js_cache = "$cache_dir/${basic_file_name}_js_cache.js";
my $cache_parsed_xml = "$cache_dir/${basic_file_name}_parsed_xml.dump";
#--- Write stuff to cache files, if cache files don't exist or are out of date:
unless (-e $js_cache && modified($js_cache)>modified($xmlfile)) {
  my $return_status = jsify($xmlfile,$js_cache);
  if ($return_status->[0]>=2) {$out = $out .  "<p>".$return_status->[1]."</p>"}
}
#----------------------------------------------------------------
# Top of page.
#----------------------------------------------------------------

$out = $out .  SpotterHTMLUtil::BannerHTML($tree);
$out = $out .  SpotterHTMLUtil::asciimath_js_code();
my $save_slurp_mode = $/;
local $/;
open(FILE,"<$js_cache");
$out = $out .  "<script>\n".<FILE>."\n</script>\n";
close FILE;
$/ = $save_slurp_mode;

SpotterHTMLUtil::debugging_output("The log file is ".Log_file::get_name());
SpotterHTMLUtil::debugging_output("The xml file is ".$xmlfile);

SpotterHTMLUtil::debugging_output("Logged in: ".$login->logged_in());
SpotterHTMLUtil::debugging_output("Username: ".$login->username());

SpotterHTMLUtil::debugging_output("class_err=".$tree->class_err());
SpotterHTMLUtil::debugging_output("class_description=".$tree->class_description());

SpotterHTMLUtil::debugging_output("priority=".getpriority(0,0));

my $fatal_error = "";
if (! -e $js_cache) {
  sleep 10; # maybe someone else is creating it right now
  if (! -e $js_cache) {"file '$js_cache' does not exist, could not be created, and was not created by another process within 10 seconds"}
}

#----------------------------------------------------------------
# Body.
#----------------------------------------------------------------

  if ($tree->class_description()) {$out = $out .  $tree->class_description()."<br>\n"}

  my $journals = $tree->journals();
  my $have_journals = defined $journals;
  my (%journals,@journals_list);
  if ($have_journals) {
    my ($a,$b) = ($journals->[0],$journals->[1]);
    %journals = %$a;
    @journals_list = @$b;
  }

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

  if (!Url::par_is("login","form")) {
    if ($login->logged_in()) {
      my $have_workfile = -e ($tree->student_work_file_name($login->username()));
      $out = $out . 
               "<b>".$tree->get_real_name($login->username(),"firstlast")."</b> logged in "
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
                                            REPLACE2=>'what',REPLACE_WITH2=>'check',DELETE_ALL=>1)."\">log out</a><br>\n";
    }
    else {
      $out = $out .  "not logged in | <a href=\"".Url::link(REPLACE=>'login',REPLACE_WITH=>'form')."\">log in</a><br>\n";
      $out = $out .  "(You can check your answers to problems without being logged in.)<p>\n";
    }
  }

  if ((!($login->logged_in())) && (!($login->login_error())) && (! Url::par_is("login","form") ) && $SpotterHTMLUtil::cgi->param('username')  && ! ($login->get_cookie()) ) {
    my $username = $SpotterHTMLUtil::cgi->param('username');
    $out = $out .  "<b>Warning: You have not successfully logged in as $username. This appears to be because your browser's preferences are set not to accept cookies from this site.</b><br>\n";
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

  if (Url::par_is("login","form")) {
    $out = $out .  do_login_form($tree);
  }
  if (Url::par_is("login","set_cookie")) {
    SpotterHTMLUtil::debugging_output("username=".$SpotterHTMLUtil::cgi->param('username'));
    SpotterHTMLUtil::debugging_output("password=".$SpotterHTMLUtil::cgi->param('password'));
  }

  if (Url::par_set("login") && !Url::par_is("login","form") && $login->login_error()) {
    $out = $out .  "<p><b>Error: ".$login->login_error()."</b></p>\n";
  }

  if (Url::par_set("login") && !Url::par_is("login","log_out") && $tree->class_err()) {
    $out = $out .  "<p><b>Error: ".$tree->class_err()."</b></p>\n";
  }


#----------------------------------------------------------
# Do real stuff.
#----------------------------------------------------------
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
        do_a_problem($xmlfile,$cache_parsed_xml,\$fatal_error,\$output,$data_dir);
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
        my $password = Login::hash($login->hash_string().$id);
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

    $out = $out .  toc_js_code(Url::param_hash()); # Fills in the <div> generated by toc_div(). See note in TODO.

  } # end if (!$fatal_error && !Url::par_is("login","form"))


sub do_a_problem {
  my ($xmlfile,$cache_parsed_xml,$fatal_err_ref,$output_ref,$data_dir) = @_;
  my $err = '';
  my $xml_data = get_xml_tree($xmlfile,$cache_parsed_xml,\$err);
  if ($err ne '') {
    $$fatal_err_ref = $err;
    $$output_ref = '';
  }
  else {
    my ($output_early,$output_middle,$output_late);
    my %params = Url::param_hash();
    my $err = do_answer_check($xml_data,\$output_early,\$output_middle,\$output_late,\%params,$login,$xmlfile,$data_dir);
    if ($err ne '') {$fatal_error = $err}
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

#---------------------------------------------------------
# Footer.
#---------------------------------------------------------

if ($fatal_error) {
  $out = $out .  "<p>Error: $fatal_error</p>\n";
}

$out = $out .  "<p>time: ".current_date_string()." CST</p>\n";

$out = $out .  SpotterHTMLUtil::accumulated_debugging_output();

$out = $out .  SpotterHTMLUtil::FooterHTML($tree);
if ($Debugging::profiling) {Log_file::write_entry(TEXT=>"done writing html output")}

#--------------------------------------------------------------------------------------------------


return $out; # all the html that has been accumulated above.

#--------------------------------------------------------------------------------------------------
} # end of run_spotter

#========================================================================================================
#========================================================================================================

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
        Email::send_email_from_student($username,$own_email,$own_name,Url::par("send_to"),$link,$body,
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
  my $url = Url::link(REPLACE=>'login',REPLACE_WITH=>'set_cookie',REPLACE2=>'what',REPLACE_WITH2=>'check');
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
    #  $out = $out . "<p>--- state=$state </p>\n";
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
        'url'=>Url::link(REPLACE=>'login',REPLACE_WITH=>'set_cookie'),
        'username'=>$username
      );
      if ($state eq 'normal') {
        $out = $out . tint('user.forgot_password',
          'url'=>Url::link(DELETE=>'login',REPLACE=>'what',REPLACE_WITH=>'emailpassword',DELETE=>'login'),
          'username'=>$username,
          'date'=>current_date_string(),
          'prompt'=>($state eq 'normal' ? ' Password:' : ' Student ID:'), # initially, password is student ID
          'activation'=>($state eq 'normal' ? tint('user.activate_account') : ''),
          'real_name'=>$tree->get_real_name($username,"firstlast"),
          'not_me_url'=>Url::link(DELETE=>'username')
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
      $data_dir
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
    $output[1] = $output[1] . handle_mathematical_answer($a,$p,$login,$xmlfile,\@hierarchy,$data_dir);
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
            if (open(FILE,"<$throttle_dir/exempt_files")) {
            while (my $line=<FILE>) {
              chomp $line;
              if ($line eq $xmlfile) {$exempt=1}
            }  
            close(FILE);
          }
          return $exempt;
}

sub kludgy_unit_fix {
          my $ans = shift;
          my $units_allowed = shift;
          # The units_allowed feature doesn't quite work right, so if units are not allowed, strip out all spaces
          # from the answer. This has the effect of making sure 2 g is interpreted as 2*g, not 2 grams. Same deal for 2 m.
          # Don't filter out all blanks, because they could be significant in, e.g., 3 10^3.
          if (!$units_allowed) {
            $ans =~ s/\s+g/g/g;
            $ans =~ s/\s+m/m/g;
          }
          return $ans;
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
  my $file = $tree->student_work_file_name($login->username());
  if ($file eq '') {return 'Error finding student work file, probably because class= was not set in the url that pointed to Spotter'}
  my $query = $args{QUERY}; # the following 4 lines are duplicated elsewhere in the code
  $query =~ s/username=[^\&]*\&?//;
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
