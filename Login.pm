package Login;

use strict;

use utf8;
use Digest::SHA;

# Login->new(...)
sub new {
  my $class = shift;
  my $username = shift;
  my $logged_in = shift;
  my $self = {};
  bless($self,$class);
  $self->username($username);
  $self->logged_in($logged_in);
  return $self;
}

sub username {
  my $self = shift;
  if (@_) {
    $self->{USERNAME} = shift;
  }
  return $self->{USERNAME};
}

sub logged_in {
  my $self = shift;
  if (@_) {
    $self->{LOGGED_IN} = shift;
  }
  return $self->{LOGGED_IN};
}

sub hash {
  my $x = shift;
  return Digest::SHA::sha1_base64($x);
}

sub salt {
  return "spotter";
}

1;
