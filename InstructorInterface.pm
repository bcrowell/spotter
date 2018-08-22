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

my $version_of_spotter = '3.0.5';
   # ... When I change this, I need to rename the subdirectory of spotter_js, e.g., from spotter_js/2.4.0 to spotter_js/2.4.1
   # ... and also change the number in Makefile
my $spotter_js_dir = "/spotter_js/$version_of_spotter";

my $log_level = 5; # normal is 2, 5 is for debugging

use Spotter;
use Login;
use FileTree;
use WorkFile;
use Query;
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
    log_entry(5,"checking password for user $username");
    if ($hash1 eq $hash2) {log_entry(1,"user $username logged in"); return $username} else {log_entry(1,"user $username, incorrect password"); return undef}
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
  log_entry(5,"entering setup()");
  if (($self->authen->username)=~/\w/) {
    $run_mode = 'do_logged_in';
  }
  if (Url::par_is("login","log_out"))    { $run_mode = 'do_log_out' }
  if (Url::par_is("login","entered_password") && ! (($self->authen->username)=~/\w/)) { $run_mode = 'public_log_in'}
  if (!Url::par_set("sid")) {$run_mode = 'public_do_login_form'} # happens if I time out?
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
  log_entry(5,"exiting setup()");
}

sub data_dir {
  return 'data'; # relative to cwd, which is typically .../cgi-bin/spotter3
}

sub log_entry {
  my ($level,$message) = @_; # level 2 is normal, 5 is for debugging
  if ($level>$log_level) {return}
  my $filename = log_file();
  open(FILE,">>$filename") or die "error writing to log file $filename, $!";
  print FILE localtime().' '.$message."\n";
  close FILE;
}

sub log_file {
  return data_dir() . "/log/instructor.log";
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
  log_entry(5,"entering public_do_login_form()");
  my $login = Login->new('',0);
  log_entry(5,"in public_do_login_form() ... 001, ref self='".(ref $self)."'");
  if (ref $self) {$self->authen->logout()}
  log_entry(5,"in public_do_login_form() ... 002");
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
  log_entry(5,"exiting public_do_login_form()");
  return run_interface($login,'public_do_login_form',0,$session);
}

sub public_log_in {
  my $self = shift;
  log_entry(5,"entering public_log_in()");
  my $login = Login->new('',0);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  log_entry(5,"exiting public_log_in()");
  return run_interface($login,'public_log_in',1,$session);
}

sub do_logged_in {
  my $self = shift;
  log_entry(5,"entering do_logged_in()");
  my $login = Login->new($self->authen->username,1);
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  log_entry(5,"exiting do_logged_in()");
  return run_interface($login,'do_logged_in',1,$session);
}

# We don't keep them in spotter for anonymous use after they log out. This is because they may not realize they're
# not logged out, and get mad when their answers aren't recorded. Instead, we send them back to the referrer page.
sub do_log_out {
  my $self = shift;
  log_entry(5,"entering do_log_out()");
  $self->authen->logout();
  my $login = Login->new('',0);
  # see notes in public_anonymous_use() for why we make session stuff even if they're not logged in
  $session = CGI::Session->load(session_id()) or die CGI::Session->errstr();
  # Don't do ->clear(), because we want to keep the referer info so they can go back to class's web page.
  log_entry(5,"exiting do_log_out()");
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

  log_entry(5,"entering run_interface()");

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

  # $out = $out . "run mode = $run_mode<p>";

  my $term = $session->param('term');
  if (Url::par_set('select_term')) {$term = Url::par('select_term')}
  if ($term) {$session->param('term',$term)}

  my $username = '';
  my $user_dir = '';
  if ($login->logged_in()) {
    $username = $login->username();
    $user_dir = user_dir($username);
    if (! defined $term) {my @a = list_terms($user_dir); $term=$a[0]}
  }

  my $class = $session->param('class');
  if (Url::par_set('select_class')) {$class = Url::par('select_class')}
  unless (is_legal_class($user_dir,$term,$class)) {$class=''; $session->param('class','')}
  if ($class) {$session->param('class',$class)}
  #$out = $out . "class = $class<p>";

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

  log_entry(5,"exiting run_interface()");

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
    push @functions,['email list',             1,{REPLACE=>'function',REPLACE_WITH=>'email_list',DELETE=>$del}];
    push @functions,['view work',             1,{REPLACE=>'function',REPLACE_WITH=>'work',DELETE=>$del}];
    push @functions,['manage student accounts',1,{REPLACE=>'function',REPLACE_WITH=>'manage_accounts',DELETE=>$del}];
    push @functions,['roster',1,{REPLACE=>'function',REPLACE_WITH=>'roster',DELETE=>$del}];
    push @functions,['export roster to OpenGrade',1,{REPLACE=>'function',REPLACE_WITH=>'export_to_og',DELETE=>$del}];
    push @functions,['add a student',1,{REPLACE=>'function',REPLACE_WITH=>'add',DELETE=>$del}];
    push @functions,['add multiple students',1,{REPLACE=>'function',REPLACE_WITH=>'add_many',DELETE=>$del}];
    push @functions,['create a new term',0,{REPLACE=>'function',REPLACE_WITH=>'create_term',DELETE=>$del}];
    push @functions,['create a new class',0,{REPLACE=>'function',REPLACE_WITH=>'create_class',DELETE=>$del}];
    push @functions,['log out',0,{REPLACE=>'login',REPLACE_WITH=>'log_out',NOT_DELETE=>'',DELETE_ALL=>1}];
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
  if ($function eq 'add_many') {($out,$fatal_error) = do_add_many(@stuff)}
  if ($function eq 'export_to_og') {($out,$fatal_error) = do_export_to_og(@stuff)}
  if ($function eq 'roster') {($out,$fatal_error) = do_roster(@stuff)}
  if ($function eq 'work') {($out,$fatal_error) = do_work(@stuff)}
  if ($function eq 'create_term') {($out,$fatal_error) = do_create_term(@stuff)}
  if ($function eq 'create_class') {($out,$fatal_error) = do_create_class(@stuff)}

  if ($run_mode eq 'do_log_out' && $session->param('referer')) {
    $out = $out . "<p><a href=\"".$session->param('referer')."\">Click here to return to the page that took you here.</a></p>"
  }

  return ($out,$fatal_error);
}

sub do_roster {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $class_dir = class_dir($user_dir,$term,$class);
  $out = $out . function_header("Roster");
  my ($k,$r,$fatal_error) = get_roster($user_dir,$class_dir,$fatal_error,1);
  my @keys = @$k; # sorted list of keys
  my @o = ();
  foreach my $key(@keys) {
    my $last = $r->{$key}->{last};
    my $first = $r->{$key}->{first};
    my $flag = '';
    if (!($r->{$key}->{disabled})) {
      push @o,"<p>$last, $first</p>"
    }
  }
  $out = $out . join("\n",@o);
  return ($out,$fatal_error);
}

sub do_work {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  $out = $out . function_header("View work: step $step");
  if ($step==1) {
    my $default_due_date = localtime_to_time_input_string(localtime(time));
    $out = $out . tint('instructor_interface.view_work_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)'),
      'default_due_date'=>$default_due_date
    );
  }
  if ($step==2) {
    my $probs = $SpotterHTMLUtil::cgi->param('problemsToView');
    my $answer_file = $SpotterHTMLUtil::cgi->param('answerFile');
    my $due_date = $SpotterHTMLUtil::cgi->param('dueDate').":00";
    ($out,$fatal_error) = get_work($out,$probs,$answer_file,$due_date,$user_dir,$class,$term,$session,$fatal_error);
  }
  return ($out,$fatal_error);
}

sub localtime_to_time_input_string { # minutes arbitrarily set to :00
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @_;
  $year = $year+1900;
  $mon = sprintf("%02d",$mon+1);
  $mday = sprintf("%02d",$mday);
  $hour = sprintf("%02d",$hour);
  return "$year-$mon-$mday $hour:00";
}

sub get_work {
  my ($out,$probs,$answer_file,$due_date,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $class_dir = class_dir($user_dir,$term,$class);
  my ($k,$r);
  ($k,$r,$fatal_error) = get_roster($user_dir,$class_dir,$fatal_error,1);
  if ($fatal_error) {return ($out,$fatal_error)}
  $probs =~ s/^\s+//; # strip leading whitespace
  $probs =~ s/\s+$//; # strip trailing whitespace
  my @p = split /\s+/,$probs;
  my @parsed_probs = ();
  foreach my $p(@p) {
    if ($p =~ /(\d+)\-([\w\d]+)/) {
      push @parsed_probs,[$1,$2];
    }
    else {
      return ($out,"Illegal format for problem number: $p");
    }
  }

  my @keys = @$k; # sorted list of keys

  # kludge: if problem 21-2 has parts a, b, and c, detect that based on which ones students actually entered answers for
  my @prob_parts = ();
  foreach my $p(@parsed_probs) {
    my $ch = $p->[0];
    my $num = $p->[1];
    my %parts = ();
    foreach my $key(@keys) {
      if (!($r->{$key}->{disabled})) {
        my $work_file = "$class_dir/$key.work";
        my $query = "file=$answer_file&chapter=$ch&problem=$num";
        my $parts = WorkFile::find_parts_that_exist($query,$work_file); # array ref
        foreach my $x(@$parts) {$parts{$x} = 1}
      }
    }
    my $parts_list = join(',',(keys %parts));
    if ($parts_list eq '') {return ($out,"Problem $ch-$num was never attempted by any student; is it really online?")}
    push @prob_parts,$parts_list;
    #$out = $out . "<p>problem $ch-$num has parts $parts_list</p>";
  }

  my @o = ();
  foreach my $key(@keys) {
    my $last = $r->{$key}->{last};
    my $first = $r->{$key}->{first};
    my $flag = '';
    if (!($r->{$key}->{disabled})) {
      my $work_file = "$class_dir/$key.work";
      my @scores = ();
      foreach my $p(@p) {push @scores,0} # by default, scores are zero
      if (-e $work_file) {
        my $i=0;
        foreach my $p(@parsed_probs) {
          my @parts = split(/,/,$prob_parts[$i]);
          my $ch = $p->[0];
          my $num = $p->[1];
          my $credit = 1;
          foreach my $part(@parts) {
            my $query = "file=$answer_file&chapter=$ch&problem=$num&find=$part";
            my $time_zone_correction = 0;
            $credit = $credit &&
                  WorkFile::look_for_correct_answer_given_work_file($query,$due_date,$time_zone_correction,$work_file);
          }
          $scores[$i] = $credit;
          $i = $i+1;
        }
      }
      push @o,"<tr><td>$last, $first</td>".join(' ',map {"<td>$_</td>"} @scores)."</tr>"
    }
  }
  my $headers = join(' ',map {"<td>$_</td>"} ('',@p));
  $out = $out . "\n<table>\n<tr>$headers</tr>" . join("\n",@o) . "</table>\n";
  return ($out,$fatal_error);
}

sub do_create_term {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  $out = $out . function_header("Create a new term: step $step");
  if ($step==1) {
    $out = $out . tint('instructor_interface.create_term_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)')
    );
  }
  if ($step==2) {
    my $term = $SpotterHTMLUtil::cgi->param('termName');
    $fatal_error = create_term($term,$user_dir,$fatal_error);
    unless ($fatal_error) {$out = $out . "Successfully created term $term"; set_term($session,$term)}
  }
  return ($out,$fatal_error);
}

sub set_term {
  my ($session,$term) = @_;
  $session->param('term',$term);
}

sub do_create_class {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  $out = $out . function_header("Create a new term: step $step");
  if ($step==1) {
    $out = $out . tint('instructor_interface.create_class_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)')
    );
  }
  if ($step==2) {
    my $class = $SpotterHTMLUtil::cgi->param('className');
    my $descr = $SpotterHTMLUtil::cgi->param('classDescription');
    $fatal_error = create_class($term,$class,$descr,$user_dir,$fatal_error);
    unless ($fatal_error) {
      my $url = make_link(REPLACE=>'step',REPLACE_WITH=>'3',DELETE=>'(user|select_term|select_class)');
      $out = $out . "<p><a href=\"$url\">Click here</a> to continue.<p>"; # kludge: already did it, but need additional step so it shows up properly at top of screen
      $session->param('save_class',$class);
      $session->param('class',$class);
    }
  }
  if ($step==3) {
    $class = $session->param('save_class');
    $session->clear('save_class');
    $session->param('class',$class);
    $out = $out . "<p>Successfully created class $class.<p>";
  }
  return ($out,$fatal_error);
}

sub create_term {
  my ($term,$user_dir,$fatal_error) = @_;
  if (!($term =~ m/^[a-z]\d\d\d\d$/)) {return "Illegal term name."}
  my $term_dir = "$user_dir/$term";
  if (-e $term_dir) {return "The directory $term_dir already exists."}
  mkdir($term_dir) or return "Error creating directory $term_dir";
  chmod 0771, $term_dir;
  # $fatal_error = set_group($term_dir,$server_group,$fatal_error); # doesn't work
  return $fatal_error;
}

sub create_class {
  my ($term,$class,$description,$user_dir,$fatal_error) = @_;
  if (!($class =~ m/^[a-z0-9]+$/)) {return "Illegal class name."}
  my $class_dir = "$user_dir/$term/$class";
  if (-e $class_dir) {return "Error -- the directory $class_dir already exists."}
  mkdir($class_dir) or return "Error creating directory $class_dir";
  chmod 0771, $class_dir;
  $description =~ s/\"//g;
  my $info_file = "$class_dir/info";
  open(FILE,">$info_file") or return "Error opening info file $info_file for output";
  print FILE "description=\"$description\"\n";
  close(FILE);
  system("chmod ug+rw $info_file");
  return $fatal_error;
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

sub do_add_many {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  my $step = Url::par('step')+0;
  my $class_dir = class_dir($user_dir,$term,$class);
  $out = $out . function_header("Add multiple students: step $step");
  if ($step==1) {
    $out = $out . tint('instructor_interface.add_many_form',
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'2',DELETE=>'(user|select_term|select_class)')
    );
  }
  if ($step==2) {
    my $t = $SpotterHTMLUtil::cgi->param('spreadsheet');
    $t =~ s/\s+$//g; # strip trailing whitespace, e.g., extra newlines
    my $table = '';
    my @lines = split /\n/,$t;
    my $first_line = 1;
    my @data = ();
    foreach my $line(@lines) {
      my @cols = split /\t/,$line;
      my @r = ();
      if ($first_line) {
        $first_line = 0;
        my $ncol=@cols;
        $table = $table . "<tr>\n";
        for (my $i=1; $i<=$ncol; $i++) {$table = $table . "<td><b>column $i</b></td>"}
        $table = $table . "\n</tr>\n";
      }
      $table = $table . "<tr>\n";
      foreach my $col(@cols) {
        $col =~ s/^\s+//; # trim leading whitespace
        $col =~ s/\s+$//; # ...and trailing whitespace
        $table = $table . "<td>$col</td> ";
        push @r,$col;
      }
      push @data,\@r;
      $table = $table . "\n</tr>\n";
    }
    my @json_rows = ();
    foreach my $r(@data) {
      push @json_rows, '[' . join(",",map {"\"$_\""} @$r) .']';
    }
    my $json = '[' . join(',',@json_rows)  . ']';
    $out = $out . tint('instructor_interface.show_spreadsheet','table'=>$table);
    $session->param('spreadsheet',$json);
    $out = $out . tint("instructor_interface.interpret_spreadsheet_form",
      'action_url'=>make_link(REPLACE=>'step',REPLACE_WITH=>'3',DELETE=>'(user|select_term|select_class)')
      );
    #$fatal_error = add_one_student($last,$first,$id,$class_dir,$fatal_error);
    #$out = $out . "first=$first last=$last id=$id";
    #unless ($fatal_error) {$out = $out . "Successfully added $last, $first, student ID $id"}
  }
  if ($step==3) {
    my $l_col = $SpotterHTMLUtil::cgi->param('lastNameColumn')-1;
    my $f_col = $SpotterHTMLUtil::cgi->param('firstNameColumn')-1;
    my $lf_col = $SpotterHTMLUtil::cgi->param('lastFirstNameColumn')-1;
    my $id_col = $SpotterHTMLUtil::cgi->param('IDColumn')-1;
    my $json = $session->param('spreadsheet');
    #$out = $out . "l_col=$l_col f_col=$f_col<p>";
    #$out = $out . "json=".$json."<p>";
    my $data = from_json($json);
    my @d = ();
    foreach my $r(@$data) {
      my ($last,$first,$id) = ('','','');
      if ($l_col>=0) {$last = $r->[$l_col]}
      if ($f_col>=0) {$first = $r->[$f_col]}
      if ($lf_col>=0) {
        my $lf = $r->[$lf_col];
        $lf =~ /(.*),(.*)/;
        ($last,$first) = ($1,$2);
      }
      if ($id_col>=0) {$id = $r->[$id_col]}
      $id =~ s/^\@//; # trim leading @ sign from FC ID numbers
      # trim leading and trailing whitespace
      $first =~ s/^\s+//;
      $first =~ s/\s+$//;
      $last =~ s/^\s+//;
      $last =~ s/\s+$//;
      $first =~ s/\s+.*//;      # trim middle initial or middle name
      $out = $out . "last=$last, first=$first, id=$id<br/>";
      push @d,[$last,$first,$id];
    }
    my @json_rows = ();
    foreach my $r(@d) {
      push @json_rows, '[' . join(",",map {"\"$_\""} @$r) .']';
    }
    my $json = '[' . join(',',@json_rows)  . ']';
    # $out = $out . "<p>$json</p>";
    $session->param('students_to_add',$json);
    my $url = make_link(REPLACE=>'step',REPLACE_WITH=>'4',DELETE=>'(user|select_term|select_class)');
    $out = $out . "<p><a href=\"$url\">Click here</a> to add these students.<p>";
  }
  if ($step==4) {
    my $json = $session->param('students_to_add');
    my $data = from_json($json);
    my ($fail,$success) = (0,0);
    foreach my $r(@$data) {
      my ($last,$first,$id) = @$r;
      $out = $out . "last=$last, first=$first, id=$id<br/>";
      my $err = add_one_student($last,$first,$id,$class_dir,'');
      if ($err) {
        $out = $out . "<p>Error adding student, last=$last, first=$first, id=$id: $err</p>";
        $fail += 1;
      }
      else {
        $success += 1;
      }
    }
    $out = $out . "$success students added successfully. $fail failures.";
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

  open(FILE,">$file") or return "unable to open file $file for output, $!";
  print FILE "last=\"$last\",first=\"$first\",id=\"$id\",disabled=\"0\"\n";
  print FILE "state=\"notactivated\",password=\"$p\"\n";
  close(FILE);
  if (!-e $file) {return "Error creating $file"}

  # $fatal_error = set_group($file,server_group(),$fatal_error); # doesn't work
  system("chmod ug+w $file");

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
    my $did_separator = 0;
    foreach my $key(@keys) {
      my $last = $r->{$key}->{last};
      my $first = $r->{$key}->{first};
      my $flag = '';
      if ($r->{$key}->{disabled}) {
        if (!$did_separator) {push @o,"<option disabled>----------</option>"; $did_separator=1}
        $flag = " (account disabled)";
      }
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

sub do_export_to_og {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  $out = $out . function_header('Export roster to OpenGrade');
  my $class_dir = class_dir($user_dir,$term,$class);
  my ($k,$r,$fatal_error) = get_roster($user_dir,$class_dir,$fatal_error,0);
  my @keys = @$k; # sorted list of keys
  my %h;
  foreach my $key(@keys) {
    my $info = $r->{$key};
    my $last = $info->{last};
    my $first = $info->{first};
    my $id = $info->{id};
    $h{$key} = {'id'=>$id};
    $key =~ m/([^_]*)_([^ \.]*)/;
    my ($l,$f) = ($1,$2);   
    if ($l ne lc($last)) {$h{$key}->{'last'} = $last}
    if ($f ne lc($first)) {$h{$key}->{'first'} = $first}
  }  
  my $r =  '"roster":'.encode_json(\%h);
  $out = $out . tint('instructor_interface.show_og','code'=>$r);
}

sub do_email_list {
  my ($out,$function,$user_dir,$class,$term,$session,$fatal_error) = @_;
  $out = $out . function_header('Email list');
  my $class_dir = class_dir($user_dir,$term,$class);
  unless (-d $class_dir) {$fatal_error = "No such directory: $class_dir, class=$class, term=$term"}
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
    if (!@l) {$out = $out . " (no classes defined yet)"}
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

sub is_legal_class {
  my ($user_dir,$term,$class) = @_;
  if (!$term) {return 0}
  my @classes = list_classes($user_dir,$term);
  foreach my $c(@classes) {
    if ($c eq $class) {return 1}
  }
  return 0;
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

sub server_group {
  return get_group("/usr/lib/cgi-bin/spotter3/data"); # fixme - shouldn't be hardcoded here
}

sub get_group {
  my $file = shift;
  # Could do this with stat function, but I'd rather work with symbolic group name, not numerical ID.
  my $listing = `ls -ld $file`; # output like --->  drwxr-xr-x    5 root     apache       4096 Jun 16  2003 /var/www/cgi-bin/$
  $listing =~ m/^\s*[^\s]+\s+\d+\s+\w+\s+([\w\-\d]+)/;
  my $group = $1;
  return $group;
}

sub set_group { # don't use, fails with operation not permitted
  my ($file,$group,$fatal_error) = @_;
  if (($file=~m/\.\./) || !($file=~m/^[\w\/\.\-]+$/)) {
    return "Illegal characters in filename, setting group of file $file"; # security
  }
  my $groups_i_am_in = `groups`;
  my $q = quotemeta $group;
  unless ($groups_i_am_in =~ /$group/) {
    return "Attempted to set group of $file to $group. You need to be a member of group $group in order to do this. The command groups tells you what groups you're a member of. To add yourself to a group, edit /etc/group, log out, and log back in.";
  }

  if (0) { # fails with operation not permitted
    chown -1,getgrnam($group),$file;
    my $err = $!;
    if (get_group($file) ne $group) {
      return "Error setting group of $file to $group, $err, trying to do chown -1,getgrnam($group),$file";
    }
  }

  return $fatal_error;
}
