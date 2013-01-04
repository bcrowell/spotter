package Login;

use strict;

use utf8;
use Digest::SHA;

# cookie is username^date^auth, where
# auth =  H[H[h+password]+date]
# h    =  HASH_STRING
# H    =  a hash function


# Login->new(...)
sub new {
  my $class = shift;
  my %args = (
    CGI=>{},                     # a CGI object from CGI.pm
    METHOD=>'cookie',            # may later implement 'get' and 'post'
    COOKIE_NAME=>'login',
    HASH_STRING=>'',             # for security, set this to some string that is specific to your site
    PASSWORD_CHECKER=>'',        # a subroutine that knows how to read password file and returns whether cookie is valid
    @_,
  );
  my $self = {};
  bless($self,$class);
  $self->cgi($args{CGI});
  $self->valid_punctuation($args{VALID_PUNCTUATION});
  $self->method($args{METHOD});
  $self->cookie_name($args{COOKIE_NAME});
  $self->hash_string($args{HASH_STRING});
  $self->password_checker($args{PASSWORD_CHECKER});
  $self->read_state();
  return $self;
}



sub username {
  my $self = shift;
  if (@_) {
    $self->{USERNAME} = shift;
  }
  return $self->{USERNAME};
}

sub date {
  my $self = shift;
  if (@_) {
    $self->{DATE} = shift;
  }
  return $self->{DATE};
}

sub auth {
  my $self = shift;
  if (@_) {
    $self->{AUTH} = shift;
  }
  return $self->{AUTH};
}


sub cgi {
  my $self = shift;
  if (@_) {
    $self->{CGI} = shift;
  }
  return $self->{CGI};
}

sub valid_punctuation {
  my $self = shift;
  if (@_) {
    $self->{VALID_PUNCTUATION} = shift;
  }
  return $self->{VALID_PUNCTUATION};
}

sub method {
  my $self = shift;
  if (@_) {
    $self->{METHOD} = shift;
  }
  return $self->{METHOD};
}

sub cookie_name {
  my $self = shift;
  if (@_) {
    $self->{COOKIE_NAME} = shift;
  }
  return $self->{COOKIE_NAME};
}

sub hash_string {
  my $self = shift;
  if (@_) {
    $self->{HASH_STRING} = shift;
  }
  return $self->{HASH_STRING};
}

sub password_checker {
  my $self = shift;
  if (@_) {
    $self->{PASSWORD_CHECKER} = shift;
  }
  return $self->{PASSWORD_CHECKER};
}

sub logged_in {
  my $self = shift;
  if (@_) {
    $self->{LOGGED_IN} = shift;
  }
  return $self->{LOGGED_IN};
}

sub login_error {
  my $self = shift;
  if (@_) {
    $self->{LOGIN_ERROR} = shift;
  }
  return $self->{LOGIN_ERROR};
}

sub strip_invalid_punctuation {
  my $self = shift;
  my $x = shift;
  $x =~ s/[^\w\_\+\.\-\'\,\:\ ]//g;
  return $x;
}


sub get_cookie {
  my $self = shift;
  return $self->cgi()->cookie($self->cookie_name());
}

# Update the login state.
sub read_state {
  my $self = shift;
  $self->logged_in(0);
  $self->login_error('');
  $self->username(undef);
  $self->date(undef);
  $self->auth(undef);
  if ($self->method() eq 'cookie') {
    my $cookie = $self->get_cookie();
    if (defined $cookie) {
      $cookie =~ m/^([^\^]*)\^([^\^]*)\^([^\^]*)$/;
      $self->username($1);
      $self->date($2);
      $self->auth($3);
    }
  }
  $self->ritual_purification(); #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  if (!($self->username() && $self->date() && $self->auth())) {return}
  if (&{$self->password_checker()}($self)) {
    $self->logged_in(1);
  }
}

sub check_password {
  my $self = shift;
  my $password_hash = shift;
  return $self->auth() eq hash($password_hash.$self->date());
}

sub cookie_value {
  my $self = shift;
  my $password = shift;
  $self->ritual_purification();
  $self->auth(hash(hash($self->hash_string().$password).$self->date()));
  return $self->username()."^".$self->date()."^".$self->auth();
}

sub ritual_purification {
  my $self = shift;
  if (defined $self->username()) {$self->username($self->strip_invalid_punctuation($self->username()))}
  if (defined $self->date())     {$self->date($self->strip_invalid_punctuation($self->date()))}
}

sub hash {
  my $x = shift;
  return Digest::SHA::sha1_base64($x);
}


1;
