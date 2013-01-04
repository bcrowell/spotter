package FileTree;

use strict;

use utf8;
use Digest::SHA1;

# FileTree->new(...)
sub new {
  my $name_of_oo_class = shift; # avoid confusion with academic "class"
  my %args = (
    DATA_DIR=>"",            # if not null, should have a trailing slash
    CLASS=>"",               # e.g. bcrowell/f2002/205
    @_,
  );
  my $self = {};
  bless($self,$name_of_oo_class);

  $self->data_dir($args{DATA_DIR});
  $args{CLASS} =~ s|[^\w/]||g; # defeat trickery like putting in ../
  $self->class($args{CLASS});
  $self->class_dir($self->data_dir() . $self->class());
  $self->class_err("");
  if (! -e $self->class_dir()) {$self->class_err("Class ".$self->class_dir()." doesn't exist.")}
  my $foo;
  if (!$self->class_err()) {
    $self->class_is_expired(0);
    my ($err,$expire) = $self->get_par_from_file($self->class_dir()."/info","expire");
    if (!$err) {
      $self->class_expire($expire);
      $expire =~ m@(\d+)/(\d+)/(\d+)@;
      my ($exp_y,$exp_m,$exp_d) = ($1,$2,$3);
      my ($now_y,$now_m,$now_d) = ((localtime)[5]+1900,(localtime)[4]+1,(localtime)[3]);
      $self->class_is_expired(
	   ($now_y>$exp_y)
        || ($now_y==$exp_y && $now_m>$exp_m)
        || ($now_y==$exp_y && $now_m==$exp_m && $now_d>$exp_d)
      );
      #$foo = "x" . $self->class_is_expired()."$exp_y/$exp_m/$exp_d, $now_y/$now_m/$now_d x";
    }
    my ($err,$description) = $self->get_par_from_file($self->class_dir()."/info","description");
    $description = $description;
    $self->class_description($description);
    #if ($err) {$self->class_err("Class has no info file. $err")}
    if ($self->class_is_expired()) {$self->class_err("Class has expired.")}
    if ($err) {$self->class_description("Untitled class ".$self->class())}
  }
  return $self;
}

sub journals {
  my $self = shift;
  my $journals_info_file = $self->class_dir()."/journals";
  if (! -e $journals_info_file) {return undef}
  open(FILE,"<$journals_info_file") or return undef;
  my %result = ();
  my @ordered_list = ();
  while (my $line = <FILE>) {
  		my ($readable,$label);
      if ($line =~ m/^\s*\"([^\"]*)\"\s*,\s*\"([^\"]*)\"\s*$/) {
        ($readable,$label) = ($1,$2);
      }
      else {
        if ($line =~ m/^\s*\"([^\"]*)\"\s*/) {
          $readable = $1;
          $label = $readable;
          $label =~ s/([^\w\d])//g;
        }
      }
      if ($readable) {
        push @ordered_list, $label;
        $result{$label}=$readable;
      }
  }
  close(FILE);
  if (0==scalar keys %result) {return undef}
  return [\%result,\@ordered_list];
}

sub read_journal {
  my $self = shift;
  my $username = shift;
  my $journal = shift;
  my $journal_file = $self->student_journal_file_name($username,$journal);
  local $/;
  undef $/; # slurp whole file
  open(FILE,"<$journal_file") or return "";
  my $text = <FILE>;
  close(FILE);
  my $is_locked = -e "$journal_file.lock";
  return ($text,$is_locked);
}

sub write_journal {
  my $self = shift;
  my $username = shift;
  my $journal = shift;
  my $text = shift;
  my $journal_file = $self->student_journal_file_name($username,$journal);
  $self->rediff_journal($username,$journal);
  my $tilde_file = $journal_file . '~';
  rename $journal_file,$tilde_file;
  set_file_permissions($tilde_file);
  open(FILE,">$journal_file") or return "error opening file $journal_file for output";
  print FILE $text;
  close(FILE);
  $self->rediff_journal($username,$journal);
  set_file_permissions($journal_file); # kludge -- chown, chgrp, chmod stuff should all be in the instructor's info file, or maybe in a global config file
  return '';
}

sub rediff_journal {
  my $self = shift;
  my $username = shift;
  my $journal = shift;
  my $diffs_dir = $self->diffs_directory();
  make_dir($diffs_dir) if ! -e $diffs_dir;
  my $student_dir = "$diffs_dir/$username";
  make_dir($student_dir) if ! -e $student_dir;
  my $journal_dir = "$student_dir/$journal";
  make_dir($journal_dir) if ! -e $journal_dir;
  my @diffs = sort <$journal_dir/*>;
  #my $debug = sub {my $msg = shift; open(DEBUG,">>$journal_dir/debug"); print DEBUG "$msg\n"; close DEBUG;};
  #&$debug('yahoo');
  local $/; # slurp whole file
  my $journal_file = $self->student_journal_file_name($username,$journal);
  open(FILE,"<$journal_file") or return;
  my $text = <FILE>;
  close FILE;
  my $hash = diff_hash($text);
  my $tilde_file = $journal_file . '~';
  open(FILE,"<$tilde_file");
  my $tilde_text = <FILE>;
  close FILE;
  my $tilde_hash = diff_hash($tilde_text);
  my $date = current_date_for_diff_file();
  # There are four possibilities:
  # (1) Everything is in order, and we don't need to do anything. The current version matches the hash after the last diff.
  # (2) The file has just been edited. The tilde version matches the hash after the last diff. We need to add a new diff.
  # (3) Something wierd has happened, and neither one matches. We need to laboriously reconstruct all the diffs.
  # (4) There are no previous diffs. This is treated the same as (3).
  my $last_diff_file = $diffs[-1]; # may be undef
  $last_diff_file =~ m/([^\-]*)$/;
  my $last_diff_hash = $1; # may be null or undef (?)
  return if ($last_diff_hash eq $hash); # (1) do nothing
  if ($last_diff_hash ne $tilde_hash || !@diffs) { # (3) or (4): reconstruct from the start; after this, continue with (2)
    # create empty file:
    my $rebuild = "$journal_dir/rebuild";
    open(FILE,">$rebuild");
    close(FILE);
    foreach my $diff(@diffs) {
      system("patch -s $rebuild $diff");
    }
    unlink "$rebuild.orig";
    rename $rebuild,$tilde_file;
    set_file_permissions($tilde_file);
    sleep 3.; # keep from making two diff files with the same time
  }
  # (2) add a new diff
  my $diff = "$journal_dir/$date-$hash";
  system("diff $tilde_file $journal_file >$diff");
  set_file_permissions($diff);
  return;
}

# Automatically adds one to month, so Jan=1, and, if year is less than
# 1900, adds 1900 to it. This should ensure that it works in both Perl 5
# and Perl 6.
sub current_date {
	my $what = shift; #=day, month, year, ...
	my @tm = localtime;
	if ($what eq "day") {return $tm[3]}
	if ($what eq "year") {my $y = $tm[5]; if ($y<1900) {$y=$y+1900} return $y}
	if ($what eq "month") {return ($tm[4])+1}
	if ($what eq "hour") {return $tm[2]}
	if ($what eq "minutes") {return $tm[1]}
	if ($what eq "seconds") {return $tm[0]}
}

sub current_date_for_diff_file() {
    return sprintf "%04d-%02d-%02d-%02d%02d%02d", current_date("year"), current_date("month") ,
    current_date("day"),current_date("hour"),current_date("minutes"),current_date("seconds");
}

sub diff_hash {
  my $text = shift;
	my $hash = Digest::SHA1::sha1_base64($text);
	$hash =~ s@/@_@g; # Unix filenames shouldn't have slashes in them.
	$hash =~ s@\+@_@g; # Plus signs also seem to cause problems.
  return $hash;  
}

sub make_dir {
  my $dir = shift;
  mkdir $dir;
  set_directory_permissions($dir);
}

sub set_directory_permissions {
  my $dir = shift;
  chmod(0755,$dir);
}

sub set_file_permissions {
  my $file = shift;
  chmod(0664,$file);
}

# Starting from class_dir, look for a file with this name. Keep going toward
# until we find it or reach data_dir. The parameter current, if present, should
# not have a trailing slash. For security, all file and directory names can only
# contain word characters and single dots.
sub search_tree_toward_root {
  my $self = shift;
  my $filename = shift;
  my $current = $self->class_dir();
  if (@_) {$current = shift}
  if ((length $current)<=(length ($self->data_dir())-1)) {return ''}
  my $check = "$current/$filename";
  $check =~ s/[^\w\.\/]//g;
  $check =~ s/\.\.//g;
  if (-e $check) {return $check}
  if ($current =~ m|^(.*)/[^/]*$|) {
    return $self->search_tree_toward_root($filename,$1);
  }
  else {
    return '';
  }
}

sub search_and_return_file_contents {
    my $self = shift;
    my $filename = shift;
    my $it = $self->search_tree_toward_root($filename);
    #print "it=$it\n";
    if ($it eq '') {return ''}
    local $/;
    undef $/; # slurp whole file
    open(F,"<$it") or return '';
    my $stuff = <F>;
    close(F);
    return $stuff;
}

# This routine will search the whole file, and return the first
# instance it finds.
sub get_par_from_file {
  my $self = shift;
  my $filename = shift;
  my $par = shift;
  open(FILE,"<$filename") or return ("file not found","");
  while (my $line = <FILE>) {
      if ($line =~ m/$par=\"([^\"]*)\"/) {return (0,$1)};
  }
  close(FILE);
  return ("data not found","");
}

sub set_par_in_file {
  my $self = shift;
  my $filename = shift;
  my $par = shift;
  my $value = shift;
  open(FILE,"<$filename") or return "file not found";
  local $/; # undefines $/, so we read in a whole file at a time
  my $contents = <FILE>;
  close(FILE);
  if ($contents =~ m/$par=\"([^\"]*)\"/) {
    $contents =~ s/$par=\"([^\"]*)\"/$par=\"$value\"/;
  }
  else {
    $contents =~ s/\n$//;
    $contents = $contents . ",$par=\"$value\"\n";
  }
  open(FILE,">$filename") or return "permission denied to write to file";
  print FILE $contents;
  close(FILE);
  return "";
}

sub get_real_name {
  my $self = shift;
  my $username = shift;
  my $order = shift;
  my ($err1,$last) = $self->get_student_par_with_err($username,"last");
  my ($err2,$first) = $self->get_student_par_with_err($username,"first");
  if (!$err1 && !$err2) {
    if ($order eq 'firstlast') {return "$first $last"} else {return "$last, $first"}
  }
  else {
    return $username;
  }
}

sub get_student_par {
  my $self = shift;
  my $username = shift;
  my $par = shift;
  my ($err,$result) = $self->get_student_par_with_err($username,$par);
  return $result;
}

sub student_par_exists {
  my $self = shift;
  my $username = shift;
  my $par = shift;
  my ($err,$result) = $self->get_student_par_with_err($username,$par);
  return ($err eq '');
}

sub get_student_par_with_err {
  my $self = shift;
  my $username = shift;
  my $par = shift;
  #print "<p>---".$self->student_info_file_name($username)."---</p>";
  return $self->get_par_from_file($self->student_info_file_name($username),$par);
}

sub set_student_par {
  my $self = shift;
  my $username = shift;
  my $par = shift;
  my $value = shift;
  return $self->set_par_in_file($self->student_info_file_name($username),$par,$value);
}

sub student_info_file_name {
  my $self = shift;
  my $username = shift;
  $username =~ s|/||g;
  my $info_file = $self->class_dir()."/".$username;
  $info_file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $info_file . ".info";
}

sub student_work_file_name {
  my $self = shift;
  my $username = shift;
  if ($self->class() eq '') {return ''} # happens if class= isn't supplied in the url for spotter
  $username =~ s|/||g;
  my $info_file = $self->class_dir()."/".$username;
  $info_file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $info_file . ".work";
}

sub student_journal_file_name {
  my $self = shift;
  my $username = shift;
  my $journal = shift;
  $username =~ s|/||g;
  my $info_file = $self->class_dir()."/".$username;
  $info_file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $info_file . ".$journal";
}

sub grade_report_file_name {
  my $self = shift;
  my $username = shift;
  $username =~ s|/||g;
  my $file = $self->class_dir()."/".$username;
  $file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $file . ".grade_report";
}


sub messages_directory {
  my $self = shift;
  my $file = $self->class_dir()."/messages";
  $file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $file;
}

sub diffs_directory {
  my $self = shift;
  my $file = $self->class_dir()."/diffs";
  $file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $file;
}

sub message_filename {
  my $self = shift;
  my $key = shift;
  my $file = $self->messages_directory()."/$key";
  $file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $file;
}

sub student_inbox {
  my $self = shift;
  my $username = shift;
  my $file = $self->messages_directory()."/$username";
  $file =~ s/[^\w\-\/]//g; # prevent trickery with .., ~, etc.
  return $file;
}

sub student_inbox_exists {
  my $self = shift;
  my $username = shift;
  return -e $self->student_inbox($username);
}

sub get_roster { # returns an array of usernames
  my $self = shift;
  my @files = glob($self->class_dir()."/*.info");
  my @roster = ();
  for (my $i=0; $i<=$#files; $i++) {
    my $info_file = $files[$i];
    if ($info_file =~ m/([^\/]*)\.info$/) {
      my $key = $1;
      my ($err,$disabled) = $self->get_par_from_file($info_file,'disabled');
      push @roster,$key unless (!$err and $disabled);
	  }
  }
  return @roster;
}

sub class_is_expired {
  my $self = shift;
  if (@_) {
    $self->{CLASS_EXPIRE} = shift;
  }
  return $self->{CLASS_EXPIRE};
}

sub class_expire {
  my $self = shift;
  if (@_) {
    $self->{CLASS_EXPIRE} = shift;
  }
  return $self->{CLASS_EXPIRE};
}

sub class_description {
  my $self = shift;
  if (@_) {
    $self->{CLASS_DESCRIPTION} = shift;
  }
  return $self->{CLASS_DESCRIPTION};
}

sub class_dir {
  my $self = shift;
  if (@_) {
    $self->{CLASS_DIR} = shift;
  }
  return $self->{CLASS_DIR};
}

sub class_err {
  my $self = shift;
  if (@_) {
    $self->{CLASS_ERR} = shift;
  }
  return $self->{CLASS_ERR};
}

sub instructor_dir {
  my $self = shift;
  my $current = $self->class_dir();
  if ((length $current)<=(length ($self->data_dir())-1)) {return ''}
  my $check = $current;
  $check =~ s/[^\w\.\/]//g;
  $check =~ s/\.\.//g;
  $check = "$check/../..";
  if (!-e $check) {return ''}
  return $check;
}

sub instructor_emails {
  my $self = shift;
  my $dir = $self->instructor_dir();
  if ($dir eq '') {return ''}
  my @files = glob "$dir/*.instructor_info";
  my %emails = ();
  foreach my $file(@files) {
    my ($err,$name) = $self->get_par_from_file($file,"name");
    if (!$err) {
      my ($err,$email) = $self->get_par_from_file($file,"email");
      $emails{$name} = $email;
    }
  }
  return \%emails;
}

sub data_dir {
  my $self = shift;
  if (@_) {
    $self->{DATA_DIR} = shift;
  }
  return $self->{DATA_DIR};
}

sub class {
  my $self = shift;
  if (@_) {
    $self->{CLASS} = shift;
  }
  return $self->{CLASS};
}


1;
