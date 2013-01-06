        # This is machine-generated code made by tint, https://github.com/bcrowell/tint .
        use strict;
        package Tint;
        use base 'Exporter';
        our @EXPORT_OK = ('tint');
        {
          my $VAR1 = {
          'responses.units_lecture' => {
                                         'text' => [
                                                     [
                                                       'lit',
                                                       'xYour answer has the wrong units, so either you made a mistake in your algebra or you entered your answer incorrectly.
A typical mistake would be to enter a+b/c+d when you really meant (a+b)/(c+d).
Scroll down for more information on how to enter answers into Spotter.
'
                                                     ]
                                                   ],
                                         'args' => []
                                       },
          'responses.sig_fig_lecture' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         'The numerical part of your answer, '
                                                       ],
                                                       [
                                                         'ref',
                                                         'raw_input'
                                                       ],
                                                       [
                                                         'lit',
                                                         ', has either too many or too few significant figures.'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'raw_input'
                                                     ]
                                         }
        };
 # evaluates to my $VAR1 = "...";, which is only evaluated the first time the function is called
          sub tint {
            my $key = shift;
            my %args = @_;
            my $dict = $VAR1;
            my $t = $dict->{$key};
            if (!defined $t) {return $t}
            my $tt = $t->{'text'};
            my $result = '';
            foreach my $x(@$tt) {
              my $type = $x->[0];
              if ($type eq 'lit') {
                $result = $result . $x->[1];
              }
              else {
                $result = $result . tint($x->[0],%args);
              }
            }
            return $result;
          }
        }
