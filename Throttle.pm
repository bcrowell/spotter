use strict;
require "Util.pm";

=head2 Throttle.pm

This module handles two somewhat related tasks: (1) Protect against a denial of service attack, or patterns of
use that have the same effect as one. (2) Keep track of how frequently a particular student has been checking
answers, and don't let them do arbitrarily many guesses in an arbitrarily short time.

=cut

use JSON 2.0;

=head3 shut_out_evil_ip()

Fighting against DOS attacks, spambots, etc.:

The file dos_log contains the following:
   ip address of most recent user
   list of all the times that that user has used Spotter
The file blocked_<date> contains a list of ip addresses that are blocked for the day.
If being attacked systematically, can set apache's httpd.conf file to deny access to
an ip address or a range of ip addresses; see http://httpd.apache.org/docs/2.0/howto/auth.html .
Basically you put something like "Deny from 85.91" at the end of the 'Directory "/usr/local/www/cgi-bin"' section.
The apache mechanism is effective against a range of IP addresses, whereas the stuff built into Spotter
below only works against an attack from a single address.

In cases where it's appropriate, this routine silently calls exit().
=cut

sub shut_out_evil_ip {
  my $throttle_dir = shift;
  my $date_string = shift;
  my $ip = shift;
  my $debug = shift; # string ref

  # The following is not really necessary, since it's better to do it from within the apache config file,
  # but it can't hurt, and this mechanism may be useful, e.g., for people who don't have permission to
  # alter their apache config files:

  my $x = get_config("block_ip_ranges");
  # $$debug = $$debug . "read config file\n";
  if (defined $x) {
    foreach my $range(@$x) {
      $range = quotemeta($range);
      if ($ip=~m/^$range/) {exit(0)}
    }
  }

  my $dos_settings = get_config("dos");
  if (!defined $dos_settings) {die "error reading dos from config.json"}
  my $time_window = $dos_settings->{"time_window"}; # seconds
  my $max_accesses = $dos_settings->{"max_accesses"}; 
   # maximum of this many accesses within time window; note that multiple users behind the same router/hub can appear as the same ip;
   # I found empirically that setting $max_accesses to 20 and $time_window to 60 caused my own students to be blocked on the first
   # day of class when they were all initializing their accounts from behind the same router.
  my $accesses_to_sleep = $dos_settings->{"accesses_to_sleep"};
   # If this many, then delay response by $sleep_time, so real users won't be likely to get blacklisted.
  my $sleep_time = $dos_settings->{"sleep_time"}; # seconds
  my $immune_ip_range = quotemeta($dos_settings->{"immune_ip_range"}); # don't block your own school

  $$debug = $$debug . "dos settings$time_window,$max_accesses,$accesses_to_sleep,$sleep_time,$immune_ip_range";

my $blocked_file_name = "$throttle_dir/blocked_$date_string";
my $dos_log = "$throttle_dir/dos_log";
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
    if ($accesses>$max_accesses && !($ip =~ /^$immune_ip_range/)) { # don't block your own school
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

}

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
