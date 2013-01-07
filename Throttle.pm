use strict;

sub throttle_file_name {
            my $throttle_dir = shift;
            my $date_string = shift;
            return "$throttle_dir/log_$date_string";
}

sub write_throttle_file {
            my $throttle_dir = shift;
            my $date_string = shift;
            my $ip = shift;
            my $who = shift;
            my $when = shift;
            my $query_sha1 = shift;
            my $throttle_file_name = throttle_file_name($throttle_dir,$date_string);
            if (open(FILE,">>$throttle_file_name")) {
              print FILE "$ip,$who,$when,$query_sha1\n";
              close(FILE);
            }
}

sub throttle_ok {
            my $throttle_dir = shift;
            my $date_string = shift;
            my $query_sha1 = shift;
            my $who = shift;
            my $when = shift;
            my $return_number = shift; # scalar ref
            my $return_longest_interval_violated = shift; # scalar ref
            my $return_when_over = shift; # scalar ref
            my $ip = shift;

            my $debug = 0;

            my $longest_interval_violated = 0;
            my $throttle_file_name = throttle_file_name($throttle_dir,$date_string);
            my %max_within = (
              10 => 1,  # no more than 1 in 10 seconds
              20 => 3,  # no more than 3 in 20 seconds
              180 => 8, # no more than 8 in 3 minutes
              600 => 15, # no more than 15 in 10 minutes
              3600 => 30, # no more than 30 in 1 hour
              86400 => 100, # no more than 100 in 1 day
            );
            my %n_within = ();
            my $max_per_day = 30; # each throttle file is 1 day
            my $throttle_ok = 1;
            my $when_over;
            if (open(FILE,"<$throttle_file_name")) {
              print "<p>opened file $throttle_file_name</p>\n" if $debug;
              my @times = ();
              while (my $line = <FILE>) {
                chomp $line;
                my ($ip_was,$who_was,$when_was,$query_sha1_was) = split /,/,$line;
                if ((($ip_was eq $ip && ($who_was eq '' || $who eq '')) || $who_was eq $who) && $query_sha1 eq $query_sha1_was && $when_was<$when) {
                  # The final sanity check on $when_was<$when would seem unnecessary, since you shouldn't have entries in the log file that are
                  # from a time that lies in the future. However, I've seen cases where this subroutine exits with
                  # when_over > longest_interval_violated, which would only seem possible if that were the case.
                  push @times,$when_was;
                  print "<p>found time $when_was</p>\n" if $debug;
                }
              }
              close(FILE);
              my $n_times = ($#times)+1;
              my @intervals = keys %max_within;

              foreach my $interval(@intervals) {
                my @within_this_interval = ();
                $n_within{$interval} = 0;
                foreach my $time(@times) {
                  if ($time+$interval>$when) {
                    ++$n_within{$interval};
                    push @within_this_interval,$time;
                  }
                }
                if ($n_within{$interval}>=$max_within{$interval}) {
                  $throttle_ok = 0;
                  if ($interval>$longest_interval_violated) {
                    $longest_interval_violated = $interval;
                    @within_this_interval = sort {$b <=> $a} @within_this_interval; # reverse numerical order
                    $when_over = $within_this_interval[$max_within{$interval}-1]+$interval-$when;
                  }
                }
              } # end loop over intervals

            } # end if throttle file exists
            if (!$throttle_ok) {
              $$return_number = $max_within{$longest_interval_violated};
              $$return_longest_interval_violated = $longest_interval_violated;
              $$return_when_over = $when_over;
            }
            return $throttle_ok;
}

1;
