package Email;

use strict;

use Mail::Sendmail;
use Tint 'tint';

my $default_from = '"Spotter at lightandmatter.com" <no-reply@lightandmatter.com>';

# send_email(TO=> , FROM=> , SUBJECT=> , BODY=>)
# FROM can be omitted, in which case it defaults to the $default_from address.
# To be polite, FROM should be of the form
#   "realname" <x@y>
# TO can be either a single address (scalar) or
# a reference to an array of addresses, to which the
# mail will be sent one at a time.

sub send_email {
  my %args = (
    FROM=>$default_from,
    @_,
  );
  my $to = $args{'TO'};
  my $from = $args{'FROM'};
  my $subject = $args{'SUBJECT'};
  my $body = $args{'BODY'};
  my $dk = $args{'DK'}; # send it via port 587, so it will be signed via domainkeys? only do this with mails for which from: is lightandmatter.com

  my @recipients = ();
  if (ref $to) {
    @recipients = @$to;
  }
  else {
    if ($to eq '') {return}
    push @recipients,$to;
  }

  my $err = '';

  my $highest_severity = 0;
  foreach my $recipient(@recipients) {
    my $r = send_an_email($recipient,$from,$subject,$body,$dk);
    my $this_err = $r->[0];
    my $this_severity = $r->[1];
    if ($this_severity>$highest_severity) {$highest_severity=$this_severity}
    $err = $err . $this_err;
    last if $this_severity >= 2;
  } # end loop over recipients

  return [$err,$highest_severity];
} # end send_mail()

sub syntactically_valid {
  my $addy = shift;
  if ($addy eq '') {return 0}
  return ($addy =~ m/.+\@.+\..+/);
}

sub send_email_from_student {
  my $from_username = shift;
  my $from_email = shift;
  my $from_name = shift;
  my $to_email = shift;
  my $link = shift;
  my $body = shift; # is null if not ready to send yet
  my $subject1 = shift;
  my $subject2 = shift;

  my $out = '';

  #print "link=$link,body=$body,sub1=$subject1,sub2=$subject2";

  $subject1 = "$subject1: ";

  my $from = '"'.$from_name.'"'." <$from_email>";
  my $from_html = '"'.$from_name.'"'." &lt;$from_email&gt;";

  my $subject = $subject1.$subject2;
  my $sent = 0;
  if ($body ne '') {
    my $r = send_an_email($to_email,$from,$subject,$body,0);
    my $err = $r->[0];
    if ($err eq '') {
      $out = $out . "<p>Your e-mail has been sent.</p>\n";
      $sent = 1;
    }
    else {
      $out = $out . "<p>Error: $err</p>\n";
    }
  }

  if (!$sent) {
    $out = $out . tint('email.not_yet_sent','from_html'=>$from_html,'to_email'=>$to_email,'link'=>$link,'subject1'=>$subject1,'body'=>$body);
  }

  if ($sent) {
    $out = $out . tint('email.send','from_html'=>$from_html,'subject'=>$subject,'body'=>$body,'to_email'=>$to_email);
  }

  return $out;
}

# Returns [$error_message,$severity]
# On success, $error_message is a null string (and $severity is undef).
# A severity of 2 indicates that sending mail isn't working, and we shouldn't try any more.
sub send_an_email {
      my $to = shift;
      my $from = shift;
      my $subject = shift;
      my $body = shift;
      my $dk = shift; # send it via port 587, so it will be signed via domainkeys? only do this with mails for which from: is lightandmatter.com

      my $err = '';
      my $severity;

      if ($err eq '' && syntactically_valid($to)) {
        my $connect = 'localhost';
        if ($dk) {
          #$connect = 'localhost:587'; # via "submission" port, which gets filtered by the dkim-signing daemon
          # commented out because not currently working for me
        }
        # But normally we don't want that, because this is how students send email with the from: being aol or whatever.
        if (Mail::Sendmail::sendmail('To'=>$to, 'From'=>$from, 'Message'=>$body, 'Subject'=>$subject, 'smtp'=>$connect)) {
          # okay
        }
        else {
          $err = "error in Mail::Sendmail::sendmail, ".$Mail::Sendmail::error;
          $severity = 2;
        }        
      } # end if valid address
      else {
        $err = "email not sent to address '$to', not a syntactically valid email address\n";
          $severity = 1;
      }
      return [$err,$severity];
}

1;
