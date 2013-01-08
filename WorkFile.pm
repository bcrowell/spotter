package WorkFile;

use strict;
use utf8;
use locale;

use FileTree;
use Query;

sub list_all_correct_answers_for_one_student {
    my $tree = shift;
    my $student = shift;
    my $work_file = $tree->student_work_file_name($student);
    my %results = ();
          my %dups = ();
          if (open(FILE,"<$work_file")) {
            while (my $line = <FILE>) {
              $line =~ m/^([^,]*),(\d+)\n?$/;
              my ($what,$n_lines) = ($1,$2);
              my ($q,$correct,$date);
              my $got_q = 0;
              for (my $i=1; $i<=$n_lines; $i++) {
                  $line = <FILE>;
                  $line =~ m/^\s*([^:]+)\:\s*([^\s].*)\n?$/;
                  my ($field,$value) = ($1,$2);
                  if ($what eq 'answer') {
                    if ($field eq 'query') {$q = Query->new($value);$got_q=1}
                    if ($field eq 'correct') {$correct = $value}
                    if ($field eq 'date') {$date = $value}
                  }
              }
              if ($got_q && $correct) {
                my $description = $q->human_readable_description;
                if (!exists $results{$description}) {
                  $results{$description} = $date;
                }
                else {
                  if (!exists $dups{$description}) {
                    $results{$description} = $results{$description} . " (input more than once)";
                  }
                  $dups{$description} = 1;
                }
              }
            }
            close FILE;
            my @k = keys %results;
            # We can actually sort these directly, but then 10 comes before 1, etc. So:
            for (my $i=0; $i<=$#k; $i++) {
              $k[$i] =~ s/(\d+)/sprintf "%04d",$1/ge;
            }
            @k = sort @k;
            for (my $i=0; $i<=$#k; $i++) {
              $k[$i] =~ s/(\d+)/sprintf "%d",$1/ge;
            }
            my @descriptions = ();
            foreach my $k(@k) {
              push @descriptions,("$k, ".$results{$k});
            }
            return ('',\@descriptions);
          } # end if file could be opened
          return ('error_opening_file',[]);
}

sub look_for_correct_answer {
          my $tree = shift;
          my $student = shift;
          my $query = shift;
          my $due_string = shift;
          my $time_zone_correction = shift; # positive if client is east of server
          my $work_file = $tree->student_work_file_name($student);
          $due_string =~ m/(\d+)-(\d+)-(\d+) (\d+):(\d+)/;
          my $due = sprintf "%04d-%02d-%02d %02d:%02d:%02d",$1,$2,$3,($4-$time_zone_correction),$5,0; # bug for nonintegral time zone
          if (open(FILE,"<$work_file")) {
            while (my $line = <FILE>) {
              $line =~ m/^([^,]*),(\d+)\n?$/;
              my ($what,$n_lines) = ($1,$2);
              my ($q,$correct,$date);
              my @date_array;
              my $got_q = 0;
              for (my $i=1; $i<=$n_lines; $i++) {
                  $line = <FILE>;
                  $line =~ m/^\s*([^:]+)\:\s*([^\s].*)\n?$/;
                  my ($field,$value) = ($1,$2);
                  if ($what eq 'answer') {
                    if ($field eq 'query') {$q = Query->new($value);$got_q=1}
                    if ($field eq 'correct') {$correct = $value}
                    if ($field eq 'date') {
                      $value =~ m/(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/;
                      $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d",$1,$2,$3,$4,$5,$6;
                      @date_array = ($6,$5,$4,$3,$2,$1);
                    }
                  }
              }
              if ($got_q && queries_are_alike($q->{STRING},$query) && $correct) {
                if ($date lt $due) {
                  close FILE;
                  return 1;
                }
              }
            }
            close FILE;
          }
          return 0;
}

sub report_answers_on_one_problem {
  my $tree = shift;
  my $problem = shift;
  my $response_data = '';
  my @roster = sort $tree->get_roster();
  my $query_to_find = (Query->new($problem))->{STRING};
  chomp $query_to_find;
  #$response_data = $response_data . "to find=".$query_to_find."\n";
  my $debug_info = '';
  my @results = ();
  foreach my $student(@roster) {
    my $work_file = $tree->student_work_file_name($student);
    if (open(FILE,"<$work_file")) {
      #$debug_info = $debug_info . "reading $student\n";
      while (my $line = <FILE>) {
        $line =~ m/^([^,]*),(\d+)\n?$/;
        my ($what,$n_lines) = ($1,$2);
        my ($query,$date) = ('','');
        my %fields = ();
        for (my $i=1; $i<=$n_lines; $i++) {
          $line = <FILE>;
          $line =~ m/^\s*([^:]+)\:\s*([^\s].*)\n?$/;
          my ($field,$value) = ($1,$2);
          if ($what eq 'answer') {
            $fields{$field} = $value;
            if ($field eq 'query') {$query = Query->new($value)}
          }
        }
        if (exists $fields{'query'}) {
          my $found = $query->{STRING};
          #if ($student eq 'seo_jin') {$debug_info = $debug_info . "checking found=$found= against $query_to_find\n";}
          if (queries_are_alike($found,$query_to_find)) {
            my $result = '';
            $result = $result . sprintf "%19s ",$fields{'date'};
            $result = $result . sprintf "%20s ",$student;
            $result = $result . sprintf " %15s ",$fields{'ip'};
            $result = $result . $fields{'answer'};
            push @results,$result;
          }
        }
      }
    } # end if successfully opened file
  } # end loop over students
  @results = sort @results;
  foreach my $result(@results) {
    $response_data = "$response_data$result\n";
  }
  return $response_data;
}

# Finds every problem that any student ever put an answer in for.
sub list_all_work {
        my $tree = shift;
        my %queries = ();
        my @roster = sort $tree->get_roster();
        foreach my $student(@roster) {
          my $work_file = $tree->student_work_file_name($student);
          if (open(FILE,"<$work_file")) {
            while (my $line = <FILE>) {
              if ($line =~ m/^([^,]*),(\d+)\n?$/) {
                my ($what,$n_lines) = ($1,$2);
                my ($query,$date) = ('','');
                for (my $i=1; $i<=$n_lines; $i++) {
                  do {
                    $line = <FILE>;
                  } while(!($line=~/:/)); # until I fixed a bug, some description: lines went on for multiple lines; handle these gracefully (if they aren't at end of record)
                  $line =~ m/^\s*([^:]+)\:\s*([^\s].*)\n?$/;
                  my ($field,$value) = ($1,$2);
                  if ($what eq 'answer') {
                    if ($field eq 'query') {$query = Query->new($value)}
                  }
                }
                if ($n_lines>=1 && $query->{'STRING'} ne '') {my $x=$query->{'STRING'}; $queries{$x}=1}
              }
              else {
                chomp $line;
                die "Error, malformed line in $work_file, line=$line=, at list_all_work() in WorkFile.pm";
              }
            }
            close FILE;
          }
        }
        return (sort keys %queries);
}

# returns the local time zone in units of hours; result may be a non-integer;
# west of Greenwich is negative
sub my_time_zone {
  my $t = time();
  my @local = localtime($t);
  my @gmt = gmtime($t);
  my $secs = ($local[0]-$gmt[0])+($local[1]-$gmt[1])*60+($local[2]-$gmt[2])*3600;
  if ($local[3]!=$gmt[3] || $local[4]!=$gmt[4] || $local[5]!=$gmt[5]) {
    if ($local[5]>$gmt[5] || ($local[5]==$gmt[5] && $local[4]>$gmt[4]) || ($local[5]==$gmt[5] && $local[4]==$gmt[4] && $local[3]>$gmt[3])) {
      $secs = $secs + 3600*24;
    }
    else {
      $secs = $secs - 3600*24;
    }
  }
  return $secs/3600.;
}

sub queries_are_alike {
  my $a = shift;
  my $b = shift;
  return filter_crap_from_query($a) eq filter_crap_from_query($b);
}

sub filter_crap_from_query {
  my $a = shift;
  my $crap = "class|username|correct|book|sid";
  $a =~ s/($crap)=[\w\d\/]+\&//g;
  $a =~ s/\&($crap)=[\w\d\/]+//g;
  return $a;
}


1;
