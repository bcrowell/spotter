#----------------------------------------------------------------
# Copyright (c) 2001 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#
#----------------------------------------------------------------

package SpotterText;

use strict;

use utf8;

sub no_equals_sign_in_answers {
  return <<HTML;
   <p>You don't need to type in an equation, just an expression. Everything
   to the left of the equals sign has been disregarded.</p>
HTML
}

sub do_not_type_units {
  return <<HTML;
   <p>For this problem, don't type in the units. Use the pop-up menu on the right.</p>
HTML
}

sub time_out {
  my $number = shift;
  my $interval = shift;
  my $expire = shift;
  return <<HTML;
            Too many answers have been entered in a short time period on this computer and/or this account.
             To discourage random guessing, longer and longer wait times are required if you
             keep on entering answers over and over.
             If you're having trouble doing this problem, maybe you should get help from your instructor!
             You have entered more than $number answers within 
             $interval seconds.
             This waiting period will expire in $expire seconds.
HTML
}

sub exempt_from_time_out {
  my $number = shift;
  my $interval = shift;
  return <<HTML;
          (This answer file is exempt from waiting time requirements, but 
               you have entered more than $number answers within 
               $interval seconds.)
HTML
}

sub anonymous_time_out {
  return <<HTML;
   <p> (Since you're using Spotter anonymously, you may get this message even if it's the first
              time you've attempted the problem. This is because Spotter considers all anonymous
              users to be the same person.)</p>
HTML
}

sub anonymous_forbidden {
  return <<HTML;
   <p>Anonymous access is not allowed from your location. Please log in.</p>
HTML
}

sub anonymous_forbidden_but_exempt {
  return <<HTML;
   <p>(Anonymous access is not normally allowed from your location,
       but this answer file is exempt from that restriction.)</p>
HTML
}

sub foo {
  return <<HTML;
   <p></p>
HTML
}

#----------------------------------------------------------------
# how_to_enter_answers
#----------------------------------------------------------------
sub how_to_enter_answers {
    return <<__HTML__;
    
    <h3>How to enter answers into Spotter</h3>
    <h4>Numerical answers</h4>
    <p>Enter the number. If there is a pop-up menu of units, select the
    units in which your answer is expressed. Never
    type in units; either select them from the menu or don't supply them at all.
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
          <tr><td> sin <sup>a</sup>/<sub>bc</sub>   </td><td><tt> sin[a/(bc)]<br/> (using (), [], and {} makes it easier<br/>for you to see what you're doing)  </tt></td></tr>
        </table>
    </ul>
    </p>
    <p>
    Spotter only checks whether your answer is <i>numerically</i> equal to the answer the
    instructor put in previously. It doesn't check whether it is in the right
    <i>form</i>. It doesn't know whether a symbolic answer has been simplified
    as much as possible, and it doesn't know whether a numerical answer has the
    right number of significant figures. It's your responsibility to check these things;
    don't try to blame it on the software if you get them wrong!
    </p>
    <p>
    For more details, you can download the documentation for Spotter 
    <a href="http://www.lightandmatter.com/spotter/spotter.html">here</a>.
    </p>
__HTML__
}


1;
