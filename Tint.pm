        # This is machine-generated code made by tint, https://github.com/bcrowell/tint .
        use strict;
        package Tint;
        use base 'Exporter';
        our @EXPORT_OK = ('tint');
        {
          my $VAR1 = {
          'journal.old_versions_form' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         '<h3>Old Versions</h3>.You have '
                                                       ],
                                                       [
                                                         'ref',
                                                         'n'
                                                       ],
                                                       [
                                                         'lit',
                                                         ' old versions you can go back and look at. To view one, enter a number from 1 to '
                                                       ],
                                                       [
                                                         'ref',
                                                         'n'
                                                       ],
                                                       [
                                                         'lit',
                                                         '.<br/>'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'n',
                                                       'n',
                                                       'url'
                                                     ]
                                         },
          'checker.your_account_form' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         '<form method="POST" action="'
                                                       ],
                                                       [
                                                         'ref',
                                                         'url'
                                                       ],
                                                       [
                                                         'lit',
                                                         '">\';'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'url',
                                                       'email',
                                                       'emailpublic'
                                                     ]
                                         },
          'responses.units_lecture' => {
                                         'text' => [
                                                     [
                                                       'lit',
                                                       'Your answer has the wrong units, so either you made a mistake in your algebra or you entered your answer incorrectly.
A typical mistake would be to enter a+b/c+d when you really meant (a+b)/(c+d).
Scroll down for more information on how to enter answers into Spotter.
'
                                                     ]
                                                   ],
                                         'args' => []
                                       },
          'journal.edit_text_form' => {
                                        'text' => [
                                                    [
                                                      'lit',
                                                      '<form method="POST" action="'
                                                    ],
                                                    [
                                                      'ref',
                                                      'url_link'
                                                    ],
                                                    [
                                                      'lit',
                                                      '">'
                                                    ]
                                                  ],
                                        'args' => [
                                                    'url_link',
                                                    'text'
                                                  ]
                                      },
          'journal.instructions' => {
                                      'text' => [
                                                  [
                                                    'lit',
                                                    '<p>If you scroll down, first you\'ll see your current version of your text with all the formatting, and then below that you\'ll 
see a window in which you can edit your text. To make a paragraph break, put in a blank line between the paragraphs. 
To make a section heading, put the heading on a line by itself, with an equals sign, =, at the beginning of the line. 
Subsection headings are made with a ==, and subsubsections with a ===. 
To make a table of data, put a * at the beginning of each line.</p>
<p>Your changes will not be saved until you click on the Save button! To avoid losing changes by mistake, you should make 
a habit of saving your text very often as you work on it.</p>
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
                                         },
          'checker.explain_answer_list' => {
                                             'text' => [
                                                         [
                                                           'lit',
                                                           '<p>The following is a list of the correct answers that have been recorded for you. If a correct answer
is missing from this list, it may be because you weren\'t logged in when you entered the answer. Even if
your correct answers shows up here, that doesn\'t necessarily mean it was on time. Note that all the times shown below
are for the time zone of the server (PST for lightandmatter.com). If you got some parts of a problem
right but not others, only the ones you got right are listed here.</p>
'
                                                         ]
                                                       ],
                                             'args' => []
                                           },
          'checker.explain_mathml' => {
                                        'text' => [
                                                    [
                                                      'lit',
                                                      '<p>As you type, Spotter\'s interpretation of your input will show up here: <span id="out"></span> <br/>
(This feature requires Firefox, or Internet Explorer 6 with <a href="http://www.dessci.com/en/products/mathplayer/welcome.asp">MathPlayer</a>.)</p>
'
                                                    ]
                                                  ],
                                        'args' => []
                                      },
          'checker.explain_email_privacy' => {
                                               'text' => [
                                                           [
                                                             'lit',
                                                             '<p><b>E-mail addresses</b></p>
<p>Important privacy information: People\'s e-mail addresses only appear here if they want them to be available to
other people in the class; this can be controlled from the account settings page. Please do not give these e-mail
addresses to anyone outside the class.</p>
'
                                                           ]
                                                         ],
                                               'args' => []
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
        1;
