#----------------------------------------------------------------
# Url class
# code duplicated in Spotter_record_work_lightweight.cgi
#----------------------------------------------------------------
package Url;

our %params = ();

# Construct URL that links back to me. The DELETE
# arg tells which params to delete, written like "a"
# to delete a=xxx only, or "(a|b)" to delete more than one.
# If DELETE_ALL is used, then NOT_DELETE is the list
# not to delete, in the same style. Don't use DELETE and
# DELETE_ALL together.
sub link {
  my %args = (
    DELETE_ALL => 0,
    RELATIVE=>1,
    DELETE=>'',
    NOT_DELETE => "(what|debug|file|class)",
    REPLACE => "",
    REPLACE_WITH => "",
    REPLACE2 => "",
    REPLACE_WITH2 => "",
    REPLACE3 => "",
    REPLACE_WITH3 => "",
    INTERFACE => "WebInterface",
    @_,
  );
    
  my $cgi = new CGI;
  my $this_script = $cgi->url(-relative=>$args{RELATIVE});
  
  # Workaround for a bug in CGI.pm: If GET and POST are both used, then
  # query_string only gives the javascript form stuff, not the URL stuff.
  #my $q = $cgi->query_string; # doesn't work
  my $q = "";
  my @u = $cgi->url_param;
  foreach my $a(@u) {
    if ($a ne "") {
      $q = $q . $a . "=" . $cgi->url_param($a) . "&"; # Extra & on the end gets cleaned up later
    }
  }

  # --- DELETE
  for (my $i=1; $i<=2; $i++) {
    my $d;
    if ($i==1) {$d = $args{DELETE}}
    if ($d ne "") {
      $q =~ s/$d=[^=\&]*//g;
    }
  }

  # --- DELETE_ALL
  if ($args{DELETE_ALL}) {
    my $nd = $args{NOT_DELETE};
    if ($nd eq "") {
      $q =~ s/[^=\&]+=[^=\&]*//g;
    }
    else {
      my $new = "";
      while ($q =~ m/($nd=[^=\&]*)/g) {
        $new = $new . $1 . "&";
      }
      $q = $new;
    }
  }
  
  # --- REPLACE
  my $r = $args{REPLACE};
  my $rw = $args{REPLACE_WITH};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }
  my $r = $args{REPLACE2};
  my $rw = $args{REPLACE_WITH2};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }
  my $r = $args{REPLACE3};
  my $rw = $args{REPLACE_WITH3};
  if ($r ne "") {
    if (!($q =~ m/$r/)) {$q=$q."&$r=$rw";}
    $q =~ s/$r=[^=\&]*/$r=$rw/;
  }

  unless ($q=~/sid=/) {
    my $sid;
    if ($args{INTERFACE} eq "WebInterface") {
      $sid = WebInterface::session_id();
    }
    if ($args{INTERFACE} eq "InstructorInterface") {
      $sid = InstructorInterface::session_id();
    }
    $q = $q . "&sid=$sid";
  } # make sure it always has this
  
  # Tidy up.
  $q =~ s/\&\&+/\&/g; # replace && with &
  $q =~ s/\&+$//g; # strip & off the end
  
  return $this_script."?".$q;
}

sub par_is {
  my ($par,$val) = @_;
  return par($par) && $params{$par} eq $val;
}

sub par_set {
  my ($par) = @_;
  return exists($params{$par});
}

sub par {
  my ($par) = @_;
  return $params{$par};
}

# only works if decode_params has been called first
sub param_hash {
  return %params;
}

sub decode_pars {

        my $my_query_string = $ENV{'QUERY_STRING'};
        #my $my_query_string = "file=lm&what=check";
                
        my @query_key_pairs = split(/&/, $my_query_string);
        
        if (! @query_key_pairs) {return 0;}
        
        %params = ();
        foreach my $par (@query_key_pairs) {
          my ($a,$b) = split(/=/, $par);
          my ($aa,$bb,$msg);
          $aa = $a;
          $bb = $b;
          ($aa,$msg) = SpotterHTMLUtil::sanity_check(TEXT=>$a,MAX_LENGTH=>50);
          ($bb,$msg) = SpotterHTMLUtil::sanity_check(TEXT=>$b,MAX_LENGTH=>50);
          $params{$aa} = $bb;
        }
}

1;
