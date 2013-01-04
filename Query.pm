#---------------------------------------------------
# Query class
# Spotter records the student's correct and incorrect answers in
# the .work file. Each entry in that file contains the GET method
# query that was in the URL the student used to specify a particular
# question out of the XML file. This package contains some code, used
# by both Spotter and ServerOG (part of the OpenGrade package), for
# sorting out those queries in a sensible order.
#---------------------------------------------------

package Query;

use strict;
use utf8;
use locale;

sub new {
  my $class = shift;
  my $raw_query = shift;
  my $self = {};
  bless($self,$class);
  $self->{HASH} = parse_query($raw_query);
  $self->canonical_order_for_query();
  return $self;
}

sub human_readable_description {
  my $self = shift;
  my $description = $self->{STRING};
  $description =~ s/\&/, /g;
  $description =~ s/\=/ /g;
  if ($description =~ m/find (\d+)/) {
    my $find = $1;
    my $part = chr(ord('a')+$find-1); # convert 1 to a, 2 to b, etc.
    $description =~ s/find $find/part $part/;
  }
  return $description;
}

sub canonical_order_for_query {
  my $self = shift;
  my $stuff = $self->{HASH};
  my $query1 = '';
  my $query2 = '';
  my $query3 = '';
  # kludge: not necessarily correct for all users:
  if (exists $stuff->{'file'}) {$query1=$query1."&file=".$stuff->{'file'}; delete $stuff->{'file'}}
  if (exists $stuff->{'book'}) {$query3=$query3."&book=".$stuff->{'book'}; delete $stuff->{'book'}}
  if (exists $stuff->{'chapter'}) {$query3=$query3."&chapter=".$stuff->{'chapter'}; delete $stuff->{'chapter'}}
  if (exists $stuff->{'problem'}) {$query3=$query3."&problem=".$stuff->{'problem'}; delete $stuff->{'problem'}}
  if (exists $stuff->{'find'}) {$query3=$query3."&find=".$stuff->{'find'}; delete $stuff->{'find'}}
  foreach my $what(sort keys %$stuff) {
    $query2 = $query2."&$what=".$stuff->{$what};
  }
  my $query = $query1.$query2.$query3;
  $query =~ s/^\&//;
  $self->{STRING} = $query;
}

sub parse_query {
  my $query = shift;
  my %stuff = ();
  while ($query =~ m/(\w+)\=([^\&]*)/g) {
    $stuff{$1} = $2;
  }
  return \%stuff;
}

sub chop_find {
  my $self = shift;
  my $h = $self->{HASH};
  delete($h->{'find'});
  $self->{STRING} =~ s/\&find=[^\&]+$//;
}

1;
