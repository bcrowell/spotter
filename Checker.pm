# provides the following classes: Options, Ans, Vbl, Problem


#----------------------------------------------------------------
# Options class
#
# When we create a new Problem object, we set its options
# using Options->new(), using all the defaults. When we hit
# an <options> tag, we push onto that problem's options stack.
# Then any new Ans objects get created with this Problem's
# options.
# When we hit the <options/> tag, we pop the options stack.
#----------------------------------------------------------------
package Options;
sub new {
  my $class = shift;
  my %args = (
    UNIT_LIST => "",
    @_
  );
  my $self = {};
  bless($self,$class);
  if ($args{UNIT_LIST}) {$self->unit_list($args{UNIT_LIST})}
  return $self;
}

sub unit_list {
  my $self = shift;
  if (@_) {$self->{UNIT_LIST} = shift;}
  if (exists($self->{UNIT_LIST})) {return $self->{UNIT_LIST}}
  return "";
}

sub units_allowed {
  my $self = shift;
  if (@_) {$self->{UNITS_ALLOWED} = shift;}
  if (exists($self->{UNITS_ALLOWED})) {return $self->{UNITS_ALLOWED}}
  return "";
}

sub debug_dump {
  my $self = shift;
  return "Options::debug_dump, unit_list=".$self->unit_list()."<br>\n";
}

#----------------------------------------------------------------
# Ans class
#----------------------------------------------------------------
package Ans;
sub new {
  my $class = shift;
  my ($e,$filter,$tol,$tol_type,$sig_figs) = (@_);
  my $self = {};
  bless($self,$class);
  $self->e($e);
  $self->filter($filter);
  $self->tol($tol);
  $self->tol_type($tol_type);
  if ($sig_figs eq '') {$sig_figs=undef}
  $self->sig_figs($sig_figs);
  $self->response("");
  return $self;
}

sub is_correct {
  my $self = shift;
  return $self->response() eq "";
}

sub debug_dump {
  my $self = shift;
  return "e=".$self->e().", filter=".$self->filter().", tol="
          .$self->tol().", tol_type=".$self->tol_type().", response="
          .$self->response().", is_correct=".$self->is_correct();
}

sub response {
  my $self = shift;
  if (@_) {$self->{RESPONSE} = shift;}
  return $self->{RESPONSE};
}

sub e {
  my $self = shift;
  if (@_) {$self->{E} = shift;}
  return $self->{E};
}

sub filter {
  my $self = shift;
  if (@_) {$self->{FILTER} = shift;}
  return $self->{FILTER};
}

sub tol {
  my $self = shift;
  if (@_) {$self->{TOL} = shift;}
  return $self->{TOL};
}

sub tol_type {
  my $self = shift;
  if (@_) {$self->{TOL_TYPE} = shift;}
  return $self->{TOL_TYPE};
}

sub sig_figs {
  my $self = shift;
  if (@_) {$self->{SIG_FIGS} = shift;}
  return $self->{SIG_FIGS};
}

sub options {
  my $self = shift;
  if (@_) {$self->{OPTIONS} = shift;}
  return $self->{OPTIONS};
}



#----------------------------------------------------------------
# Vbl class
#----------------------------------------------------------------
package Vbl;
sub new {
  my $class = shift;
  my $sym = shift;
  my $self = {};
  bless($self,$class);
  $self->{SYM} = $sym;
  # Note that all the defaults get filled in by the XML parser. -- may no longer be true with XML::Parser, so do it here:
  $self->min(0);
  $self->max(1);
  $self->min_imag(0);
  $self->max_imag(0);
  return $self;
}

sub debug_print {
  my $self = shift;
  print $self->debug_dump();
}

sub debug_dump {
  my $self = shift;
  my $result = "<p>";
  $result = $result . $self->sym().", ".$self->description().", ".$self->type().", ";
  $result = $result . "real(".$self->min().",".$self->max()."), ";
  $result = $result . "imag(".$self->min_imag().",".$self->max_imag().")</p>\n";
  return $result;
}

sub sym {
  my $self = shift;
  if (@_) {$self->{SYM} = shift;}
  return $self->{SYM};
}

sub description {
  my $self = shift;
  if (@_) {$self->{DESCRIPTION} = shift;}
  return $self->{DESCRIPTION};
}

sub type {
  my $self = shift;
  if (@_) {$self->{TYPE} = shift;}
  return $self->{TYPE};
}

sub units {
  my $self = shift;
  if (@_) {$self->{UNITS} = shift;}
  return $self->{UNITS};
}

sub min {
  my $self = shift;
  if (@_) {$self->{MIN} = shift;}
  return $self->{MIN};
}

sub max {
  my $self = shift;
  if (@_) {$self->{MAX} = shift;}
  return $self->{MAX};
}

sub min_imag {
  my $self = shift;
  if (@_) {$self->{MIN_IMAG} = shift;}
  return $self->{MIN_IMAG};
}

sub max_imag {
  my $self = shift;
  if (@_) {$self->{MAX_IMAG} = shift;}
  return $self->{MAX_IMAG};
}

sub parsed_units {
  my $self = shift;
  if (@_) {$self->{PARSED_UNITS} = shift;}
  return $self->{PARSED_UNITS};
}


#----------------------------------------------------------------
# Problem class
#----------------------------------------------------------------
package Problem;

sub new {
  my $class = shift;
  my $id = 0;
  if (@_) {$id=shift}

  my $self = {};
  bless($self,$class);
  $self->{ID} = $id;
  my %empty = ();
  $self->{VBLS} = \%empty;
  my @empty = ();
  $self->{ORDERED_VBLS} = \@empty;
  my @empty2 = ();
  $self->{ANSWERS} = \@empty2; # does [] work?
  $self->{OPTIONS_STACK} = [Options->new()];
  $self->{TYPE} = 'expression'; # the default
  return $self;
}

sub vbl_hash {
  my $self = shift;
  my $h = $self->{VBLS};
  return %$h;
}

sub vbl_list {
  my $self = shift;
  my $r = $self->{ORDERED_VBLS};
  return @$r;
}

sub add_vbl {
  my $self = shift;
  my $vbl = shift;
  my $vbls = $self->{VBLS};
  $vbls->{$vbl->sym()}=$vbl;
  my $r = $self->{ORDERED_VBLS};
  push @$r,$vbl->sym();
}

sub add_ans {
  my $self = shift;
  my $ans = shift;
  my $answers = $self->{ANSWERS};
  push @$answers,$ans;
}

sub n_ans {
  my $self = shift;
  my $answers = $self->{ANSWERS};
  return $#$answers;
}

sub get_ans {
  my $self = shift;
  my $i = shift;
  if ($i>$self->n_ans()) {return "";}
  my $answers = $self->{ANSWERS};
  return $answers->[$i];
}

sub get_vbl {
  my $self = shift;
  my $sym = shift;
  my $vbls = $self->{VBLS};
  return $vbls->{$sym};
}

sub id {
  my $self = shift;
  if (@_) {$self->{ID} = shift;}
  return $self->{ID};
}

sub type {
  my $self = shift;
  if (@_) {$self->{TYPE} = shift;}
  return $self->{TYPE};
}

sub description {
  my $self = shift;
  if (@_) { $self->{DESCRIPTION} = shift;}
  return $self->{DESCRIPTION};
}

sub options_stack_not_empty {
  my $self = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  return ($#stack>=0);
}

sub options_stack_top {
  my $self = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  if ($#stack>=0) {return $stack[$#stack]}
  return "";
}

sub options_stack_push {
  my $self = shift;
  my $o = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  push @stack , $o;
  $self->{OPTIONS_STACK} = \@stack;
}

sub options_stack_pop {
  my $self = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  pop @stack;
  $self->{OPTIONS_STACK} = \@stack;
}

sub options_stack_dup {
  my $self = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  my $o_ref = $stack[$#stack];
  my %o = %$o_ref;
  my %o_clone = %o;
  bless(\%o_clone,"Options");
  push @stack , \%o_clone;
  $self->{OPTIONS_STACK} = \@stack;
}

sub debug_dump {
  my $self = shift;
  my $stack_ref =  $self->{OPTIONS_STACK};
  my @stack = @$stack_ref;
  my $result = "";
  $result = $result. "Problem::debug_dump, options stack depth=".$#stack."<br>\n";
  for (my $i=0; $i<=$#stack; $i++) {
    $result = $result . $i. ": ".$stack[$i]->debug_dump();
  }
  return $result;
}

1;
