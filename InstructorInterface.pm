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

  $out = $out . "run mode = $run_mode<p>";

  my $term = $session->param('term');
  if (Url::par_set('select_term')) {$term = Url::par('select_term')}
  if ($term) {$session->param('term',$term)}
  my $class = $session->param('class');
  if (Url::par_set('select_class')) {$class = Url::par('select_class')}
  if ($class) {$session->param('class',$class)}

  my $username = '';
  my $user_dir = '';
  if ($login->logged_in()) {
    $username = $login->username();
    $user_dir = user_dir($username);
    if (! defined $term) {my @a = list_terms($user_dir); $term=$a[0]}
  }

  $out = class_selection($out,$user_dir,$term,$class) if $login->logged_in();

  $out = show_functions($out,$login,$class);

  my $function = '';
  if (Url::par_set('function')) {$function = Url::par('function')}

  ($out,$fatal_error) = do_function($out,$function,$user_dir,$class,$term,$session,$fatal_error,$run_mode);
  if ($fatal_error) {  $out = $out .  "<p>Error: $fatal_error</p>\n"; }

  $out = $out . tint('instructor_interface.footer_html');

  if ($run_mode eq 'do_log_out') {$session->delete()}

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
  my $class = shift;

  if ($login->logged_in()) {
    my @functions = ();
    # description,class must be selected,url parameters
    my $del = '(user|select_term|select_class|login)';
    push @functions,['log out',0,{REPLACE=>'login',REPLACE_WITH=>'log_out',NOT_DELETE=>'',DELETE_ALL=>1}];
    push @functions,['email list',             1,{REPLACE=>'function',REPLACE_WITH=>'email_list',DELETE=>$del}];
    push @functions,['manage student accounts',1,{REPLACE=>'function',REPLACE_WITH=>'manage_accounts',DELETE=>$del}];
    push @functions,['add a student',1,{REPLACE=>'function',REPLACE_WITH=>'add',DELETE=>$del}];
    $out = $out . "<p>".join(' | ',map {
      my $x = $_;
      my ($label,$class_required,$pars) = ($x->[0],$x->[1],$x->[2]);
      my @pars_array = %$pars;
      @pars_array = (@pars_array,REPLACE2=>'step',REPLACE_WITH2=>'1');
      my $result = $label; # deactivated by default
      unless ($class_required && !$class) {
        my $link = make_link(@pars_array);
        $result = "<a href=\"$link\">$label</a>";
      }
      $result
    } @functions)."</p>\n";
  }

  return $out;
}

sub make_link {
  return Url::link (
    INTERFACE => "InstructorInterface",
    DELETE=>'(user|select_term|select_class|function)',
    @_,
  );
}

sub do_function {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error,$run_mode) = @_;

  if ($run_mode eq 'public_log_in' || $run_mode eq 'public_roster') {
    $out = $out .  public_do_login_form($out,$function,$user_dir,$class,$term,$session,$fatal_error);
  }

  my @stuff = ($out,$function,$user_dir,$class,$term,$session,$fatal_error);
  if ($function eq 'email_list') {($out,$fatal_error) = do_email_list(@stuff)}
  if ($function eq 'manage_accounts') {($out,$fatal_error) = do_manage_accounts(@stuff)}
  if ($function eq 'add') {($out,$fatal_error) = do_add(@stuff)}

  if ($run_mode eq 'do_log_out' && $session->param('referer')) {
    $out = $out . "<p><a href=\"".$session->param('referer')."\">Click here to return to the page that took you here.</a></p>"
  }

  return ($out,$fatal_error);
}

sub do_add {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  my $class_dir = class_dir($user_dir,$term,$class);
  $out = $out . function_header("Add a student: step $step");
  if ($step==1) {
    $out = $out . tint('instructor_interface.add_student_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)')
    );
  }
  if ($step==2) {
    my $first = $SpotterHTMLUtil::cgi->param('firstName');
    my $last = $SpotterHTMLUtil::cgi->param('lastName');
    my $id = $SpotterHTMLUtil::cgi->param('studentID');
    $fatal_error = add_one_student($last,$first,$id,$class_dir,$fatal_error);
    #$out = $out . "first=$first last=$last id=$id";
    unless ($fatal_error) {$out = $out . "Successfully added $last, $first, student ID $id"}
  }
  return ($out,$fatal_error);
}

sub add_one_student {
  my ($last,$first,$id,$dir,$fatal_error) = @_;

  my $last = ucfirst($last);
  my $first = ucfirst($first);
  my $key = $last."_".$first;
  $key = lc($key);
  $key =~ s/[^a-z\-_]//g;

  my $p = Digest::SHA::sha1_base64("spotter".$id);

  my $file = "$dir/$key.info";

  if (-e $file) { return "Error: file $file already exists"}

  open(FILE,">$file") or return { "unable to open file $file for output\n$!"}
  print FILE "last=\"$last\",first=\"$first\",id=\"$id\",disabled=\"0\"\n";
  print FILE "state=\"notactivated\",password=\"$p\"\n";
  close(FILE);
  if (!-e $file) {return "Error creating $file"}
  $fatal_error = set_group($file,$server_group,$fatal_error); # dies if there's an error
  system("chmod ug+w $file");

  return $fatal_error;

}

sub set_group {
  my ($file,$group,$fatal_error) = @_;
  if (($file=~m/\.\./) || !($file=~m/^[\w\/\.\-]+$/)) {
    return "Illegal characters in filename, setting group of file $file"; # security
  }
  my $groups_i_am_in = `groups`;
  my $q = quotemeta $group;
  unless ($groups_i_am_in =~ /$group/) {
    return "Attempted to set group of $file to $group. You need to be a member of group $group in order to do this. The command groups tells you what groups you're a member of. To add yourself to a group, edit /etc/group, log out, and log back in.";
  }
  my $cmd = "chgrp $group $file";
  system("$cmd");
  my $err = $!;
  if (get_group($file) ne $group) {
    return "Error setting group of $file to $group, $err, command $cmd";
  }

  return $fatal_error;
}


sub do_manage_accounts {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  my $class_dir = class_dir($user_dir,$term,$class);
  $out = $out . function_header("Manage student accounts: step $step");
  my ($k,$r,$fatal_error) = get_roster($user_dir,$class_dir,$fatal_error,1);
  my @keys = @$k; # sorted list of keys
  if ($step==1) {
    my @o = ();
    foreach my $key(@keys) {
      my $last = $r->{$key}->{last};
      my $first = $r->{$key}->{first};
      my $flag = '';
      if ($r->{$key}->{disabled}) {$flag = " (account disabled)"}
      push @o,"<option value=\"$key\">$last, $first$flag</option>";
    }
    $out = $out . tint('instructor_interface.select_student_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)'),
      'html_for_options'=>join("\n",@o)
    );
  }
  if ($step==2) {
    my $key = $SpotterHTMLUtil::cgi->param('select_student');
    my $d = $r->{$key};
    my $last = $d->{last};
    my $first = $d->{first};
    my $disabled = $d->{disabled};
    $session->param('student_key',$key);
    $out = $out . "<h2>$last, $first</h2>\n";
    $out = $out . "<p>The student's account is ".($disabled ? "disabled" : "not disabled").".</p>\n";
    $out = $out . "<p>Actions:</p>";
    my @actions = (
      # ['drop',1,'Drop'], # don't allow, requires shelling out
      ['disable',!$disabled,'Disable account'],
      ['enable',$disabled,'Reenable account'],
    );
    foreach my $action(@actions) {
      my ($verb,$allowed,$description) = ($action->[0],$action->[1],$action->[2]);
      if ($allowed) {
        my $url = make_link(REPLACE=>'step',REPLACE_WITH=>'3',REPLACE2=>'verb',REPLACE_WITH2=>$verb,DELETE=>'(user|select_term|select_class)');
        $out = $out . "<p><a href=\"$url\">$description</a></p>\n";
      }
      else {
        $out = $out . "<p>$description</p>\n";
      }
    }
    my $url_to_go_back = make_link(REPLACE=>'step',REPLACE_WITH=>'1',DELETE=>'(user|select_term|select_class|verb)');
    $out = $out . "<p><a href=\"$url_to_go_back\">Back to student selection</a></p>\n";
  }
  if ($step==3) {
    my $key = $session->param('student_key');
    my $d = $r->{$key};
    my $last = $d->{last};
    my $first = $d->{first};
    $out = $out . "<h2>$last, $first</h2>\n";
    my $verb = $SpotterHTMLUtil::cgi->param('verb');
    $fatal_error = drop_disable_or_enable_account($key,$verb,$user_dir,$class_dir,$fatal_error);
    #$out = $out . "would have done $verb";
    unless ($fatal_error) {$out = $out . "Action successfully completed: $verb"}
  }
  return ($out,$fatal_error);
}

sub drop_disable_or_enable_account {
  my ($key,$verb,$user_dir,$class_dir,$fatal_error) = @_;
  if ($verb eq 'enable' || $verb eq 'disable') {
    my $info_file = "$class_dir/$key.info";
    open(FILE,"<$info_file") or die "Error opening file $info_file for input";
    my $stuff = '';
    while (my $line= <FILE>) {
      $stuff = $stuff .  $line;
    }
    close(FILE);
    $stuff =~ s/disabled=\"0\"/disabled=\"1\"/ if $verb eq 'disable';
    $stuff =~ s/disabled=\"1\"/disabled=\"0\"/ if $verb eq 'enable';
    open(FILE,">$info_file") or die "Error opening file $info_file for output";
    print FILE $stuff;
    close(FILE);
  }
  return $fatal_error;
}

sub do_email_list {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  $out = $out . function_header('Email list');
  my $class_dir = class_dir($user_dir,$term,$class);
  unless (-d $class_dir) {$fatal_error = "No such directory: $class_dir"}
  if (!$fatal_error) {
    my @info_files = glob("$class_dir/*.info");
    my @list = ();
    foreach my $info(@info_files) {
      my ($d,$fatal_error) = get_student_info($info,$fatal_error);
      my %d = %$d;
      if ($d{state} eq 'normal' && $d{disabled} ne '1' && $d{email}=~/\w/) {
        push @list,$d{email};
      }
    }
    $out = $out . (join ',',@list);
  }
  return ($out,$fatal_error);
}

sub get_roster { # returns an array ref of keys and a hash ref of hash refs, {'smith_john'=>{'email'=>'...',...},...}
  my ($user_dir,$class_dir,$fatal_error,$include_disabled) = @_;
  my %roster = ();
  unless (-d $class_dir) {$fatal_error = "No such directory: $class_dir"}
  if (!$fatal_error) {
    my @info_files = glob("$class_dir/*.info");
    foreach my $info(@info_files) {
      my ($d,$fatal_error) = get_student_info($info,$fatal_error);
      my %d = %$d;
      my $include = 1;
      if (!$include_disabled && $d{disabled} eq '1') {$include=0}
      my $key = student_info_filename_to_key($info);
      $roster{$key} = $d if $include;
    }
  }
  my @sorted_keys = sort {sort_student_keys($a,$roster{$a}->{disabled},$b,$roster{$b}->{disabled})} keys %roster;
  return (\@sorted_keys,\%roster,$fatal_error);
}

sub sort_student_keys {
  my ($a,$a_disabled,$b,$b_disabled) = @_;
  if ($a_disabled && !$b_disabled) {return 1}
  if ($b_disabled && !$a_disabled) {return -1}
  return $a cmp $b;
}

sub student_info_filename_to_key {
  my $info = shift;
  $info =~ /([\w\-]+)\.info$/;
  return $1;
}

sub get_student_info {
  my $info = shift;
  my $fatal_error = shift;
  open(F,"<$info") or $fatal_error="error opening file $info for input, $!";
  local $/; # slurp whole file
  my $data = <F>;
  close F;
  my %h = ();
  while ($data=~/(\w+)\=\"([^"]*)\"/g) {
    $h{$1} = $2;
  }
  return (\%h,$fatal_error);  
}

sub function_header {
  my $title = shift;
  return "<h2>$title</h2>\n";
}

sub class_selection {
  my ($out,$user_dir,$term,$class) = @_;

  $out = $out . "<p><b>Term:</b> ";
  my @terms = list_terms($user_dir);
  my @l = ();
  foreach my $t(@terms) {
    if ($t eq $term) {
      push @l,("<b>".$t."</b>"); # the one they have already selected
    }
    else {
      push @l,("<a href=\"".make_link(REPLACE=>'select_term',REPLACE_WITH=>$t,DELETE=>'(user|select_class|function)') . "\">$t</a>");
    }
  }
  $out = $out . join(' | ',@l);
  $out = $out . "</p>";

  if ($term ne '') {
    $out = $out . "<p><b>Class:</b> ";
    my @classes = list_classes($user_dir,$term);
    my @l = ();
    foreach my $c(@classes) {
      if ($c eq $class) {
        push @l,("<b>".$c."</b>"); # the one they have already selected
      }
      else {
        push @l,("<a href=\"".make_link(REPLACE=>'select_class',REPLACE_WITH=>$c,DELETE=>'(user|select_term|function)') . "\">$c</a>");
      }
    }
    $out = $out . join(' | ',@l);
    $out = $out . "</p>";
  }
  
  return $out;
}

sub class_dir {
  my $user_dir = shift;
  my $term = shift;
  my $class = shift;
  if (!$class || !$term) {return undef}
  return $user_dir . "/" . $term . "/" . $class;
}

sub list_classes {
  my $user_dir = shift;
  my $term = shift;
  my $term_dir = $user_dir . "/" . $term;
  my @classes = ();
  foreach my $f(glob "$term_dir/*") {
    if (-d $f) { 
      $f =~ m@([^/]+)$@;
      push @classes, $1;
    }
  }
  return @classes;
}

sub list_terms {
  my $user_dir = shift;
  my @terms = ();
  foreach my $t(glob "$user_dir/*") {
      if (-d $t) {
        $t =~ m@([^/]+)$@;
        push @terms, $1;
      }
  }
  @terms = sort { -compare_terms($a,$b) } @terms; # reverse chronological order
  return @terms;
}

sub compare_terms {
  my ($a,$b) = @_;
  my %season_order = ('w'=>1,'s'=>2,'f'=>3);
  my ($as,$ay) = parse_term($a);  
  my ($bs,$by) = parse_term($b);
  if ($ay!=$by) {return $ay <=> $by}
  return $season_order{$as} <=> $season_order{$bs};
}

sub parse_term {
  my $term = shift;
  $term =~ m@(\w)(\d+)@;
  return ($1,$2);
}


#--------------------------------------------------------------------------------------------------


sub do_login_form {
  my $username = Url::par("user");
  my $state = '';
  my $out = '';
  $out = $out . "<b>Instructor: $username</b><br>\n";
  $out = $out . tint('instructor_interface.password_form',
    'url'=>make_link(REPLACE=>'login',REPLACE_WITH=>'entered_password'),
    'username'=>$username,
  );
  return $out;
}
