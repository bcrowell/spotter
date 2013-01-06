#----------------------------------------------------------------
# Log_file class
#----------------------------------------------------------------
package Log_file;

BEGIN {

my $log_file_name = "log";
my $start = [Time::HiRes::gettimeofday]; # start time, for profiling
my $last = $start;

sub set_name {
  my $basic_file_name = shift;
  my $ext = shift;
  my $data_dir = shift;
  $ext =~ m/^\.?([a-zA-Z0-9\_]{1,30})$/;
  if (!$1) {$ext="log"} else {$ext = $1;}
  my $dir = "$data_dir/log";
  mkdir($dir) unless -d $dir;
  $log_file_name = "$dir/$basic_file_name.$ext";
  if (!-e $log_file_name) {
    open(FILE,">$log_file_name");
    close FILE;
  }
  SpotterHTMLUtil::debugging_output("Setting log file to $log_file_name");
}

sub get_name {
  return $log_file_name; 
}

sub write_entry {
  my %args = (
    TEXT => "",
    @_
  );
  my $text = $args{TEXT};
  #print "logging text=$text=<br/>\n";
  
  my ($s,$min,$h,$d,$mo,$y) = (localtime)[0..5];
  my $t = [Time::HiRes::gettimeofday]; # more fine grained, for profiling
  my $delta = Time::HiRes::tv_interval($last,$t);
  my $delta_start = Time::HiRes::tv_interval($start,$t);
  $last = $t;
  if ($y<1900) {$y=$y+1900} # This should work in either Perl 5 or Perl 6.
  my $stuff = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d (%4.2f,%4.2f) ", $y, ($mo+1), $d, $h, $min, $s, $delta,$delta_start) 
    . $text
          . "\n";
  
  
  my $ok = open(LOG_FILE, ">>$log_file_name");
  if (!$ok) {
    print "logging failed\n";
    return;
  }
  print LOG_FILE $stuff;
  close(LOG_FILE);
 }

}

1;
