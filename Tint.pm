        # This is machine-generated code made by tint, https://github.com/bcrowell/tint .
        use strict;
        package Tint;
        use base 'Exporter';
        our @EXPORT_OK = ('tint');
        {
          my $VAR1 = {
          'user.activate_account' => {
                                       'text' => [
                                                   [
                                                     'lit',
                                                     '<p><i>To activate your account, you will need to choose a password, and enter it twice below to make sure
you haven\'t made a mistake in typing.</i><br>
<table><tr><td>Password:</td><td><input type="password" name="newpassword1" size="20" maxlength="20"></td></tr>
<tr><td>Type the same password again:</td>
<td><input type="password" name="newpassword2" size="20" maxlength="20"></td></tr></table>
<p><i>Please enter your e-mail address. This is optional, but you may miss important information about the class if 
you don\'t give an address. E-mail is also required in order to reset a forgotten password. 
Nobody outside of the class will know this address.</i><br>
<input type="text" name="email" size="50" maxlength="50"><br>
<input type="checkbox" name="emailpublic" checked value="public"> Leave this box checked if you want other students in 
the class to have access to this e-mail address.<br>
'
                                                   ]
                                                 ],
                                       'args' => []
                                     },
          'instructor_interface.banner_html' => {
                                                  'text' => [
                                                              [
                                                                'lit',
                                                                '    <h1>Instructor\'s interface for Spotter</h1>
    <p><a href="http://www.lightandmatter.com/spotter/spotter.html">About Spotter</a>.<p/>

'
                                                              ]
                                                            ],
                                                  'args' => []
                                                },
          'instructor_interface.add_student_form' => {
                                                       'text' => [
                                                                   [
                                                                     'lit',
                                                                     '<form method="POST" action="'
                                                                   ],
                                                                   [
                                                                     'ref',
                                                                     'action_url'
                                                                   ],
                                                                   [
                                                                     'lit',
                                                                     '">
      First name: <input type="text" name="firstName"><br/>
      Last name: <input type="text" name="lastName"><br/>
      Student ID: <input type="text" name="studentID"><br/>
<br>
<input type="submit" name="submitAddStudentButton" value="Add">
</form>
'
                                                                   ]
                                                                 ],
                                                       'args' => [
                                                                   'action_url'
                                                                 ]
                                                     },
          'user.blank_password' => {
                                     'text' => [
                                                 [
                                                   'lit',
                                                   'You didn\'t enter a password. Please use the back button in your browser and try again.
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
                                                         ', has either too many or too few significant figures.
As a rule of thumb, the precision of the result of a calculation is limited by the precision of the least accurate piece of data used to calculate it.
A common mistake is to believe in the fallacy of false precision suggested by your calculator\'s willingness to display a result with many digits.
when you communicate such a result to someone else, you are misleading them (and possibly also deluding yourself).
The precision of a result can also be limited by all the simplifying assumptions that went into translating a real-world situation into
equations; for example, even if I know that a rock is being dropped from a height of 1.000000 m in a gravitational field of 9.82237 m/s<sup>2</sup>,
I can\'t calculate the time it takes to hit the ground to 6 sig figs, because at that level of precision, air resistance would be an important factor.
'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'raw_input'
                                                     ]
                                         },
          'instructor_interface.create_term_form' => {
                                                       'text' => [
                                                                   [
                                                                     'lit',
                                                                     '<p>Each term has a name like s2003 for spring 2003, etc. The name must consist of
a single letter followed by four digits.</p>

<form method="POST" action="'
                                                                   ],
                                                                   [
                                                                     'ref',
                                                                     'action_url'
                                                                   ],
                                                                   [
                                                                     'lit',
                                                                     '">
      Name of term: <input type="text" name="termName"><br/>
<br>
<input type="submit" name="createTermButton" value="Create">
</form>
'
                                                                   ]
                                                                 ],
                                                       'args' => [
                                                                   'action_url'
                                                                 ]
                                                     },
          'user.not_same_password_twice' => {
                                              'text' => [
                                                          [
                                                            'lit',
                                                            'You didn\'t type the same password twice. Please use the back button in your browser and try again.
'
                                                          ]
                                                        ],
                                              'args' => []
                                            },
          'journal.is_locked' => {
                                   'text' => [
                                               [
                                                 'lit',
                                                 'This is your final version, and it can no longer be edited.
'
                                               ]
                                             ],
                                   'args' => []
                                 },
          'user.forgot_password' => {
                                      'text' => [
                                                  [
                                                    'lit',
                                                    '<p><i>Forgot your password?</i><br>
If you\'ve forgotten your password, enter your student ID number and click on this button. Information will be e-mailed to you about 
how to set a new password.<br>
<form method="POST" action="'
                                                  ],
                                                  [
                                                    'ref',
                                                    'url'
                                                  ],
                                                  [
                                                    'lit',
                                                    '">
  Student ID: <input type="hidden" name="username" value="'
                                                  ],
                                                  [
                                                    'ref',
                                                    'username'
                                                  ],
                                                  [
                                                    'lit',
                                                    '">
  <input type="text" name="id" size="10"> 
  <input type="submit" value="Send e-mail.">
</form>
'
                                                  ]
                                                ],
                                      'args' => [
                                                  'url',
                                                  'username'
                                                ]
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
                                             },
          'journal.old_versions_form' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         '<h3>Old Versions</h3>\\nYou have '
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
                                                         '\\n<br/>
<form method="POST" action="'
                                                       ],
                                                       [
                                                         'ref',
                                                         'url'
                                                       ],
                                                       [
                                                         'lit',
                                                         '">
<input type="text" name="version">
<input type="submit" name="oldJournalButton" value="View">\'
</form>
<p><b>If you have edited your text, make sure to save it before doing this!</b></p>
'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'n',
                                                       'n',
                                                       'url'
                                                     ]
                                         },
          'journal.edit_page' => {
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

<h2>Last Saved Version</h2>'
                                               ],
                                               [
                                                 'ref',
                                                 'cooked_text'
                                               ],
                                               [
                                                 'lit',
                                                 '<p/>
<h2>Edit</h2>
'
                                               ],
                                               [
                                                 'ref',
                                                 'form'
                                               ],
                                               [
                                                 'lit',
                                                 '
'
                                               ],
                                               [
                                                 'ref',
                                                 'old'
                                               ],
                                               [
                                                 'lit',
                                                 '
'
                                               ]
                                             ],
                                   'args' => [
                                               'cooked_text',
                                               'form',
                                               'old'
                                             ]
                                 },
          'boilerplate.header_html' => {
                                         'text' => [
                                                     [
                                                       'lit',
                                                       '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://www.w3.org/Math/XSL/mathml.xsl"?>
<HTML xmlns="http://www.w3.org/1999/xhtml"><HEAD>
<TITLE>'
                                                     ],
                                                     [
                                                       'ref',
                                                       'title'
                                                     ],
                                                     [
                                                       'lit',
                                                       '</TITLE>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
<! -- stuff for ASCIIMath: -->
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<style type="text/css"><!--
p.journal
{
    margin-bottom:4px;
    margin-top:4px;
    text-indent:0em;
    line-height: 1.2em;
}
h3.journal
{
    font-family:sans-serif;
    line-height:1;
}
h4.journal
{
    font-family:sans-serif;
    line-height:1;
}
h5.journal
{
    font-family:sans-serif;
    line-height:1;
}
-->
</style>
</HEAD>
<script src="'
                                                     ],
                                                     [
                                                       'ref',
                                                       'spotter_js_dir'
                                                     ],
                                                     [
                                                       'lit',
                                                       '/ASCIIMathML.js"></script>
<body  bgcolor="white" onload="init_asciimath_inputs()">
'
                                                     ]
                                                   ],
                                         'args' => [
                                                     'title',
                                                     'spotter_js_dir'
                                                   ]
                                       },
          'checker.anonymous_forbidden' => {
                                             'text' => [
                                                         [
                                                           'lit',
                                                           '   <p>Anonymous access is not allowed from your location. Please log in.</p>
'
                                                         ]
                                                       ],
                                             'args' => []
                                           },
          'instructor_interface.footer_html' => {
                                                  'text' => [
                                                              [
                                                                'lit',
                                                                '</body></html>
'
                                                              ]
                                                            ],
                                                  'args' => []
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
          'boilerplate.footer_html' => {
                                         'text' => [
                                                     [
                                                       'lit',
                                                       '<p>On-the fly rendering of mathematics is done by Peter Jipsen\'s <a href=\\"http://asciimathml.sourceforge.net\\">ASCIIMath</a>.</p>
'
                                                     ],
                                                     [
                                                       'ref',
                                                       'footer_file'
                                                     ],
                                                     [
                                                       'lit',
                                                       '
</body></html>
'
                                                     ]
                                                   ],
                                         'args' => [
                                                     'footer_file'
                                                   ]
                                       },
          'user.password_form' => {
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
                                                  '">
  <input type="hidden" name="authen_username" value="'
                                                ],
                                                [
                                                  'ref',
                                                  'username'
                                                ],
                                                [
                                                  'lit',
                                                  '">
  <input type="hidden" name="destination" value="'
                                                ],
                                                [
                                                  'ref',
                                                  'url'
                                                ],
                                                [
                                                  'lit',
                                                  '" />
  '
                                                ],
                                                [
                                                  'ref',
                                                  'prompt'
                                                ],
                                                [
                                                  'lit',
                                                  '
    <input type="password" name="authen_password" size="20" maxlength="20"><br>
  '
                                                ],
                                                [
                                                  'ref',
                                                  'activation'
                                                ],
                                                [
                                                  'lit',
                                                  '
  <input type="submit" value="Log in.">
</form>
If you\'re not '
                                                ],
                                                [
                                                  'ref',
                                                  'real_name'
                                                ],
                                                [
                                                  'lit',
                                                  ', <a href="'
                                                ],
                                                [
                                                  'ref',
                                                  'not_me_url'
                                                ],
                                                [
                                                  'lit',
                                                  '">click here</a>.<p>
'
                                                ]
                                              ],
                                    'args' => [
                                                'url',
                                                'username',
                                                'url',
                                                'prompt',
                                                'activation',
                                                'real_name',
                                                'not_me_url'
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
          'check_if_cookies_enabled' => {
                                          'text' => [
                                                      [
                                                        'lit',
                                                        '<script type="text/javascript">
    // based on code by balexandre, http://stackoverflow.com/questions/531393/how-to-detect-if-cookies-are-disabled-is-it-possible
    function test_cookie_create(name, value, days) {
        var expires;
        if (days) {
            var date = new Date();
            date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = "; expires=" + date.toUTCString();
        }
        else expires = "";
        document.cookie = name + "=" + value + expires + "; path=/";
    }

    function test_cookie_read(name) {
        var nameEQ = name + "=";
        var ca = document.cookie.split(\';\');
        for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) == \' \') c = c.substring(1, c.length);
            if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
        }
        return null;
    }

    function test_cookie_erase(name) {
        test_cookie_create(name, "", -1);
    }

    function test_cookies_enabled() {
        var r = false;
        test_cookie_create("testing", "Hello", 1);
        if (test_cookie_read("testing") != null) {
            r = true;
            test_cookie_erase("testing");
        }
        return r;
    }
</script>
'
                                                      ]
                                                    ],
                                          'args' => []
                                        },
          'instructor_interface.header_html' => {
                                                  'text' => [
                                                              [
                                                                'lit',
                                                                '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://www.w3.org/Math/XSL/mathml.xsl"?>
<HTML xmlns="http://www.w3.org/1999/xhtml"><HEAD>
<TITLE>'
                                                              ],
                                                              [
                                                                'ref',
                                                                'title'
                                                              ],
                                                              [
                                                                'lit',
                                                                '</TITLE>
</HEAD>
'
                                                              ]
                                                            ],
                                                  'args' => [
                                                              'title'
                                                            ]
                                                },
          'instructor_interface.password_form' => {
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
                                                                  '">
  <input type="hidden" name="authen_username" value="'
                                                                ],
                                                                [
                                                                  'ref',
                                                                  'username'
                                                                ],
                                                                [
                                                                  'lit',
                                                                  '">
  <input type="hidden" name="destination" value="'
                                                                ],
                                                                [
                                                                  'ref',
                                                                  'url'
                                                                ],
                                                                [
                                                                  'lit',
                                                                  '" />
  Password:
    <input type="password" name="authen_password" size="20" maxlength="20"><br>
  <input type="submit" value="Log in.">
</form>
<p>
'
                                                                ]
                                                              ],
                                                    'args' => [
                                                                'url',
                                                                'username',
                                                                'url'
                                                              ]
                                                  },
          'checker.no_equals_sign_in_answers' => {
                                                   'text' => [
                                                               [
                                                                 'lit',
                                                                 '   <p>You don\'t need to type in an equation, just an expression. Everything
   to the left of the equals sign has been disregarded.</p>
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
          'checker.time_out' => {
                                  'text' => [
                                              [
                                                'lit',
                                                '            Too many answers have been entered in a short time period on this computer and/or this account.
             To discourage random guessing, longer and longer wait times are required if you
             keep on entering answers over and over.
             If you\'re having trouble doing this problem, maybe you should get help from your instructor!
             You have entered more than '
                                              ],
                                              [
                                                'ref',
                                                'number'
                                              ],
                                              [
                                                'lit',
                                                ' answers within 
             '
                                              ],
                                              [
                                                'ref',
                                                'interval'
                                              ],
                                              [
                                                'lit',
                                                ' seconds.
             This waiting period will expire in '
                                              ],
                                              [
                                                'ref',
                                                'expire'
                                              ],
                                              [
                                                'lit',
                                                ' seconds.
'
                                              ]
                                            ],
                                  'args' => [
                                              'number',
                                              'interval',
                                              'expire'
                                            ]
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
                                                      '">
<textarea name="journalText" rows="30" cols="85">
'
                                                    ],
                                                    [
                                                      'ref',
                                                      'text'
                                                    ],
                                                    [
                                                      'lit',
                                                      '
</textarea><br/>
<input type="submit" name="submitJournalButton" value="Save">\'
</form>\\n
'
                                                    ]
                                                  ],
                                        'args' => [
                                                    'url_link',
                                                    'text'
                                                  ]
                                      },
          'checker.anonymous_time_out' => {
                                            'text' => [
                                                        [
                                                          'lit',
                                                          '   <p> (Since you\'re using Spotter anonymously, you may get this message even if it\'s the first
              time you\'ve attempted the problem. This is because Spotter considers all anonymous
              users to be the same person.)</p>
'
                                                        ]
                                                      ],
                                            'args' => []
                                          },
          'email.not_yet_sent' => {
                                    'text' => [
                                                [
                                                  'lit',
                                                  '  <form method="POST" action="'
                                                ],
                                                [
                                                  'ref',
                                                  'link'
                                                ],
                                                [
                                                  'lit',
                                                  '">
  <table>
  <tr><td>From:</td><td>'
                                                ],
                                                [
                                                  'ref',
                                                  'from_html'
                                                ],
                                                [
                                                  'lit',
                                                  '</td></tr>
  <tr><td>To:</td><td>'
                                                ],
                                                [
                                                  'ref',
                                                  'to_email'
                                                ],
                                                [
                                                  'lit',
                                                  '</td></tr></table>
  <tr><td>Subject:</td><td>'
                                                ],
                                                [
                                                  'ref',
                                                  'subject1'
                                                ],
                                                [
                                                  'lit',
                                                  '
  <input type="text" name="emailSubject" size="50" maxlength="50" value="'
                                                ],
                                                [
                                                  'ref',
                                                  'subject2'
                                                ],
                                                [
                                                  'lit',
                                                  '">
  </td></tr>
  <tr><td colspan="2">
  <textarea name="emailBody" rows="30" cols="100">
  '
                                                ],
                                                [
                                                  'ref',
                                                  'body'
                                                ],
                                                [
                                                  'lit',
                                                  '
  </textarea><br/>
  <input type="submit" name="submitEmailButton" value="Send">
  </td></tr>
  </table>
  </form>
'
                                                ]
                                              ],
                                    'args' => [
                                                'link',
                                                'from_html',
                                                'to_email',
                                                'subject1',
                                                'subject2',
                                                'body'
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
          'checker.exempt_from_time_out' => {
                                              'text' => [
                                                          [
                                                            'lit',
                                                            '          (This answer file is exempt from waiting time requirements, but 
               you have entered more than '
                                                          ],
                                                          [
                                                            'ref',
                                                            'number'
                                                          ],
                                                          [
                                                            'lit',
                                                            ' answers within 
               '
                                                          ],
                                                          [
                                                            'ref',
                                                            'interval'
                                                          ],
                                                          [
                                                            'lit',
                                                            ' seconds.)
'
                                                          ]
                                                        ],
                                              'args' => [
                                                          'number',
                                                          'interval'
                                                        ]
                                            },
          'checker.do_not_type_units' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         '   <p>For this problem, don\'t type in the units. Use the pop-up menu on the right.</p>
'
                                                       ]
                                                     ],
                                           'args' => []
                                         },
          'checker.anonymous_forbidden_but_exempt' => {
                                                        'text' => [
                                                                    [
                                                                      'lit',
                                                                      '   <p>(Anonymous access is not normally allowed from your location,
       but this answer file is exempt from that restriction.)</p>
'
                                                                    ]
                                                                  ],
                                                        'args' => []
                                                      },
          'boilerplate.default_banner_html' => {
                                                 'text' => [
                                                             [
                                                               'lit',
                                                               '    <table><tr><td><img src="http://www.lightandmatter.com/spotter/spotterlogo.jpg" width="123" height="184"></td><td>
    <h1>Spotter</h1>
    <p>A numerical and symbolic answer<br/>
       checker for math and science students.</p>
    <p><a href="http://www.lightandmatter.com/spotter/spotter.html">About Spotter</a>.<p/>

    </td></tr></table>
'
                                                             ]
                                                           ],
                                                 'args' => []
                                               },
          'checker.your_account_form' => {
                                           'text' => [
                                                       [
                                                         'lit',
                                                         '<p><b>Your Account</b><p>
<form method="POST" action="'
                                                       ],
                                                       [
                                                         'ref',
                                                         'url'
                                                       ],
                                                       [
                                                         'lit',
                                                         '">
<p>E-mail address:<br>
<input type="text" name="email" size="50" maxlength="50" value="'
                                                       ],
                                                       [
                                                         'ref',
                                                         'email'
                                                       ],
                                                       [
                                                         'lit',
                                                         '"><br>
<input type="checkbox" name="emailpublic" '
                                                       ],
                                                       [
                                                         'ref',
                                                         'emailpublic'
                                                       ],
                                                       [
                                                         'lit',
                                                         ' value="public"> 
   Check this box if you want other students in
   the class to have access to this e-mail address.<br>
<p>If you want to change your password, enter the new one twice below. If you don\'t want to change your password, don\'t
type in these boxes.<br>
<table><tr><td>New password:</td><td><input type="password" name="newpassword1" size="20" maxlength="20"></td></tr>
<tr><td>New password again:</td>
<td><input type="password" name="newpassword2" size="20" maxlength="20"></td></tr></table>
<p><i>The current settings on your account are given above. To change them, edit the form and then enter
your password at the bottom of the form and press the Change Settings button.</i>
<p>Password:  <input type="password" name="password" size="20" maxlength="20">
(If you\'re not changing your password, enter your old one here.)<br>
  <input type="submit" value="Change Settings">
</form>
'
                                                       ]
                                                     ],
                                           'args' => [
                                                       'url',
                                                       'email',
                                                       'emailpublic'
                                                     ]
                                         },
          'boilerplate.asciimath_js_code' => {
                                               'text' => [
                                                           [
                                                             'lit',
                                                             '//--------------- begin javascript code -------------------
//script to render Spotter input using MathML, via ASCIIMath

//a modification by B. Crowell of the script ASCIIMathCalculator.js by Peter Jipsen

//(c) Peter Jipsen http://www.chapman.edu/~jipsen
//(c) B. Crowell

//Requires http://www.chapman.edu/~jipsen/mathml/ASCIIMathML.js

//License: GNU General Public License (http://www.gnu.org/copyleft/gpl.html)


AMinitSymbols();

function init_asciimath_inputs() {
  var li = document.getElementsByTagName("input");
  var st;
  for (var i=0; i<li.length; i++) {
    st = li[i].getAttribute("onkeyup");
    if (st!=null) eval(String(st).replace(/function anonymous\\(\\)/,""));
  }
}


function render(inputId,outputId,variables) {
  var str = document.getElementById(inputId).value;
  var outnode = document.getElementById(outputId);
  var n = outnode.childNodes.length;
  for (var i=0; i<n; i++)
    outnode.removeChild(outnode.firstChild);
  str = str.replace(/\\*\\*/g,"^"); // Spotter allows fortran-style use of ** for exponentiation
  var cooked = new Array();
  for (var i=0; i<variables.length; i++) {
   var u = variables[i];
   var v = format_variable_name(u);
   if (u!=v) str = str.replace(new RegExp(u,"g"),v);
  }
  if (AMisMathMLavailable() != null) {
    str = \'--This feature is not available in your browser.--\';
  }
  else  {
    str = "`"+str+"`";
  }
  outnode.appendChild(document.createTextNode(str));
  AMprocessNode(outnode);
}

// exmaples: alpha1 -> alpha_(1) , mus -> mu_(s) , Ftotal -> F_(total)
// problems: operators like eq will get treated as variables, rendered as e_(q)
// Escaped dollar signs in the following for use with tint.
function format_variable_name(x) {
  y = x.replace(/^(alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)(.*)$/g,"$1_($2)");
  if (y!=x) return y;
  y = x.replace(/^(.)(.+)$/,"$1_($2)");
  return y;
}
//--------------- end javascript code -------------------
'
                                                           ]
                                                         ],
                                               'args' => []
                                             },
          'checker.how_to_enter_answers' => {
                                              'text' => [
                                                          [
                                                            'lit',
                                                            '    <h3>How to enter answers into Spotter</h3>
    <h4>Numerical answers</h4>
    <p>Enter the number. If there is a pop-up menu of units, select the
    units in which your answer is expressed. Never
    type in units; either select them from the menu or don\'t supply them at all.
    Enter scientific
    notation like this: <tt>3.0 10^8</tt> means 3.0x10<sup>8</sup>. 
    </p>
    <h4>Symbolic answers</h4>
    <p>Examples:
    <ul>
        <table border="1" width="600">
          <tr><td>ab (a multiplied by b)</td><td><tt>ab</tt></td></tr>
          <tr><td> x<sup>2</sup> (x squared)    </td><td><tt> <tt>x^2</tt>  </tt></td></tr>
          <tr><td> x<sub>2</sub> (name contains a subscript)    </td><td><tt> <tt>x2</tt>  </tt></td></tr>
          <tr><td> square root of 2   </td><td><tt> sqrt(2)  </tt></td></tr>
          <tr><td> sin x   </td><td><tt>  sin x </tt></td></tr>
          <tr><td> sin<sup>-1</sup> x   </td><td><tt> asin x  </tt></td></tr>
          <tr><td> sin<sup>2</sup>x   </td><td><tt> (sin x)^2  </tt></td></tr>
          <tr><td> sin 2x   </td><td><tt> sin(2x) (parentheses required)  </tt></td></tr>
          <tr><td> <sup>a</sup>/<sub>bc</sub>   </td><td><tt> a/(bc) (parentheses required)  </tt></td></tr>
          <tr><td> &pi;   </td><td><tt> pi (not 3.14) </tt></td></tr>
          <tr><td> e<sup>x</sup>   </td><td><tt> e^x </tt></td></tr>
<!--          <tr><td> <math  xmlns="http://www.w3.org/1998/Math/MathML"><mfrac><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow><mrow><mi>c</mi><mo>+</mo><mi>d</mi></mrow></mfrac></math>   </td><td><tt> e^x </tt></td></tr> -->
          <tr><td>
           <table><tr><td>a+b</td></tr><tr><td><pre>---</pre></td></tr></tr><td>c+d</td></tr></table> 
          </td><td><tt> (a+b)/(c+d) (parentheses required) </tt></td></tr>
          <tr><td> sin <sup>a</sup>/<sub>bc</sub>   </td><td><tt> sin[a/(bc)]<br/> (using (), [], and {} makes it easier<br/>for you to see what you\'re doing)  </tt></td></tr>
        </table>
    </ul>
    </p>
    <p>
    Spotter only checks whether your answer is <i>numerically</i> equal to the answer the
    instructor put in previously. It doesn\'t check whether it is in the right
    <i>form</i>. It doesn\'t know whether a symbolic answer has been simplified
    as much as possible, and it doesn\'t know whether a numerical answer has the
    right number of significant figures. It\'s your responsibility to check these things;
    don\'t try to blame it on the software if you get them wrong!
    </p>
    <p>
    For more details, you can download the documentation for Spotter 
    <a href="http://www.lightandmatter.com/spotter/spotter.html">here</a>.
    </p>
'
                                                          ]
                                                        ],
                                              'args' => []
                                            },
          'email.send' => {
                            'text' => [
                                        [
                                          'lit',
                                          '  <table>
  <tr><td>From:</td><td>'
                                        ],
                                        [
                                          'ref',
                                          'from_html'
                                        ],
                                        [
                                          'lit',
                                          '</td></tr>
  <tr><td>To:</td><td>'
                                        ],
                                        [
                                          'ref',
                                          'to_email'
                                        ],
                                        [
                                          'lit',
                                          '</td></tr></table>
  <tr><td>Subject:</td><td>'
                                        ],
                                        [
                                          'ref',
                                          'subject'
                                        ],
                                        [
                                          'lit',
                                          '
  </td></tr>
  <tr><td colspan="2">
  <p>'
                                        ],
                                        [
                                          'ref',
                                          'body'
                                        ],
                                        [
                                          'lit',
                                          '</p>
  </td></tr>
  </table>
'
                                        ]
                                      ],
                            'args' => [
                                        'from_html',
                                        'to_email',
                                        'subject',
                                        'body'
                                      ]
                          },
          'instructor_interface.create_class_form' => {
                                                        'text' => [
                                                                    [
                                                                      'lit',
                                                                      '<p>Each class has a name, which must be a string of digits and lowercase letters.
</p>
<form method="POST" action="'
                                                                    ],
                                                                    [
                                                                      'ref',
                                                                      'action_url'
                                                                    ],
                                                                    [
                                                                      'lit',
                                                                      '">
      Name of class (see above): <input type="text" name="className"><br/>
      Description of class: <input type="text" name="classDescription"><br/>
<br>
<input type="submit" name="createClassButton" value="Create">
</form>
'
                                                                    ]
                                                                  ],
                                                        'args' => [
                                                                    'action_url'
                                                                  ]
                                                      },
          'instructor_interface.select_student_form' => {
                                                          'text' => [
                                                                      [
                                                                        'lit',
                                                                        '<form method="POST" action="'
                                                                      ],
                                                                      [
                                                                        'ref',
                                                                        'action_url'
                                                                      ],
                                                                      [
                                                                        'lit',
                                                                        '">
<select name="select_student">
'
                                                                      ],
                                                                      [
                                                                        'ref',
                                                                        'html_for_options'
                                                                      ],
                                                                      [
                                                                        'lit',
                                                                        '
</select> 
<input type="submit" name="submitStudentButton" value="Select">
</form>
'
                                                                      ]
                                                                    ],
                                                          'args' => [
                                                                      'action_url',
                                                                      'html_for_options'
                                                                    ]
                                                        }
        };
 # evaluates to my $VAR1 = "...";, which is only evaluated when the module is first imported
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
                $result = $result . $args{$x->[1]};
              }
            }
            return $result;
          }
        }
        1;
