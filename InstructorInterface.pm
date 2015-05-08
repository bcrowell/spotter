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
use WorkFile;
use BulletinBoard;
use Email;
use AnswerResponse;
use SpotterHTMLUtil;
require "Util.pm";
use Debugging;
use Url;
use Log_file;
use Tint 'tint';

use Message;
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
    my $info_file = user_dir($username) . "/$username.instructor_info";
    my $hash1 = '';
    if (-e $info_file) { # if no such user, file doesn't exist
      $hash1 = FileTree::get_par_from_file(undef,$info_file,'password_hash');
    }
    my $hash2 = Digest::SHA::sha1_base64("spotter_instructor_password",$password);
    if ($hash1 eq $hash2) {return $username} else {return undef}
  } ],
  POST_LOGIN_RUNMODE => 'do_logged_in',
  LOGIN_RUNMODE => 'public_do_login_form',
  LOGOUT_RUNMODE => 'do_log_out',
  STORE => ['Cookie',
        NAME   => 'login',
        SECRET => 'not really so secret', # for my application, I don't care if they can forge a cookie
        EXPIRY => '+1d',
    ],
);
InstructorInterface->authen->protected_runmodes(qr/^(?!public_)/); # runmodes not starting with public_ are protected

sub setup {
  my $self = shift;
  my $run_mode = 'public_do_login_form';
  if (($self->authen->username)=~/\w/) {
    $run_mode = 'do_logged_in';
  }
  if (Url::par_is("login","log_out"))    { $run_mode = 'do_log_out' }
  if (Url::par_is("login","entered_password") && ! (($self->authen->username)=~/\w/)) { $run_mode = 'public_log_in'}
  $self->start_mode($run_mode);
  $self->run_modes([qw/
    public_do_login_form
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

sub user_dir {
  my $username = shift;
  return data_dir() . '/' . $username;
}

sub tree {
  my $data_dir = data_dir();
  return FileTree->new(DATA_DIR=>"${data_dir}/",CLASS=>Url::par("class")); # fixme - no class= in url
}

sub session_id {
  return Url::par('sid') if Url::par_set('sid');
  return $session->id if ref($session);
  return undef;
}

#========================================================================================================
# run modes
#========================================================================================================

sub public_do_login_form {
  my $self = shift;

  my $login = Login->new('',0);
  $self->authen->logout();
  $session = CGI::Session->new() or die $session->errstr;
  $session->expire(3600); 
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
  return run_interface($login,'public_do_login_form',0,$session);
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

  $SpotterHTMLUtil::cgi = new CGI;
  my $out = ''; # accumulate all the html code to be printed out

  my $language;
  ($out,$fatal_error,$language) = get_language($out,$fatal_error); # for use in Tint; not currently implemented

  $out = $out .  tint('instructor_interface.header_html');
  $out = $out .  tint('instructor_interface.banner_html');

  my $tree = tree();

  $out = show_functions($out,$login);

  ($out,$fatal_error) = do_function($out,$session,$fatal_error,$run_mode);
  if ($fatal_error) {  $out = $out .  "<p>Error: $fatal_error</p>\n"; }

  $out = $out . tint('instructor_interface.footer_html');

  if ($run_mode eq 'do_log_out' || $run_mode eq 'public_anonymous_use') {$session->delete()}

  $out = $out . "run mode = $run_mode<p>";
  if ($run_mode eq 'public_do_login_form') {$out = $out . do_login_form()}

  $session->flush();

  return $out; # all the html that has been accumulated above.

} # end of run_interface

sub get_language {
  my ($out,$fatal_error) = @_;
  my $language = get_config("language");
  if (!defined $language) {$fatal_error = "Error reading configuration file config.json, or it didn't define language."}
  return ($out,$fatal_error,$language);
}

sub show_functions {
  my $out = shift; # append onto this
  my $login = shift;

  if ($login->logged_in()) {
    $out = $out . 
               " | <a href=\"".Url::link(INTERFACE=>'InstructorInterface',REPLACE=>'login',REPLACE_WITH=>'log_out',
                                            NOT_DELETE=>'',DELETE_ALL=>1)."\">log out</a><br>\n";
  }

  return $out;
}

sub do_function {
  my $out = shift; # append onto this
  my $session = shift;
  my $fatal_error = shift;
  my $run_mode = shift;

  if ($run_mode eq 'public_log_in' || $run_mode eq 'public_roster') {
    $out = $out .  public_do_login_form();
  }

  if ($run_mode eq 'do_log_out' && $session->param('referer')) {
    $out = $out . "<p><a href=\"".$session->param('referer')."\">Click here to return to the class's web page.</a></p>"
  }

  return ($out,$fatal_error);
}


#--------------------------------------------------------------------------------------------------


sub do_login_form {
  my $username = Url::par("user");
  my $state = '';
  my $out = '';
  $out = $out . "<b>Instructor: $username</b><br>\n";
  $out = $out . tint('instructor_interface.password_form',
    'url'=>Url::link(INTERFACE=>'InstructorInterface',REPLACE=>'login',REPLACE_WITH=>'entered_password'),
    'username'=>$username,
  );
  return $out;
}
