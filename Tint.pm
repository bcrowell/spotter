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
                                                    '">\';
  <input type="text" name="id" size="10"> \';
  <input type="submit" value="Send e-mail.">\';
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
                                                         '">\';
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
  <input type="hidden" name="username" value="'
                                                ],
                                                [
                                                  'ref',
                                                  'username'
                                                ],
                                                [
                                                  'lit',
                                                  '">
  <input type="hidden" name="date" value="'
                                                ],
                                                [
                                                  'ref',
                                                  'date'
                                                ],
                                                [
                                                  'lit',
                                                  '">
  '
                                                ],
                                                [
                                                  'ref',
                                                  'prompt'
                                                ],
                                                [
                                                  'lit',
                                                  '
    <input type="password" name="password" size="20" maxlength="20"><br>
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
You must have cookies enabled in your browser in order to log in.<p>
'
                                                ]
                                              ],
                                    'args' => [
                                                'url',
                                                'username',
                                                'date',
                                                'prompt',
                                                'activation',
                                                'real_name',
                                                'not_me_url'
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
