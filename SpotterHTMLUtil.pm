#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2001 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#----------------------------------------------------------------

package SpotterHTMLUtil;

use CGI;
use FileTree;

our $cgi;
my $debugging_is_active = 0;

our $homepath = '';
our $title = 'Spotter';

sub PrintHTTPHeader {
        my $cookie_list = shift;
        print $cgi->header(-type=>'text/html',-cookie=>$cookie_list,-expires=>'now');
	        # the 'expires' part refers to cache control, not cookies.
	#print "Pragma: no-cache\nCache-control: private\nContent-Type: text/html\n\n";


}


sub PrintHeaderHTML
{
        my $spotter_js_dir = shift;
	print HeaderHTML($homepath,$title,$spotter_js_dir);
}

sub HeaderHTML
{
	my ($homepath,$title,$spotter_js_dir) = @_;

    return <<__HTML__;
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://www.w3.org/Math/XSL/mathml.xsl"?>
<HTML xmlns="http://www.w3.org/1999/xhtml"><HEAD>
<TITLE>$title</TITLE>
<META HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
<! -- stuff for ASCIIMath: -->
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<style type="text/css">
<!--
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
<script src="$spotter_js_dir/ASCIIMathML.js"></script>
<body  bgcolor="white" onload="init_asciimath_inputs()">
__HTML__
} 

sub activate_debugging_output {
  $debugging_is_active = 1;
}

sub debugging_output {
  if (!$debugging_is_active) {return}
  my $msg = shift;
  print "<p>--- $msg</p>\n";
}

sub BannerHTML
{
  my $tree = shift;
  my $result =  $tree->search_and_return_file_contents('banner.html');
  if ($result ne '') {return $result}
  return <<DEFAULT_BANNER;
    <table><tr><td><img src="http://www.lightandmatter.com/spotter/spotterlogo.jpg" width="123" height="184"></td><td>
    <h1>Spotter</h1>
    <p>A numerical and symbolic answer<br/>
       checker for math and science students.</p>
    <p><a href="http://www.lightandmatter.com/spotter/spotter.html">About Spotter</a>.<p/>

    </td></tr></table>
DEFAULT_BANNER
}

sub FooterHTML
{
  my $tree = shift;
  return "<p>On-the fly rendering of mathematics is done by Peter Jipsen's <a href=\"http://asciimathml.sourceforge.net\">ASCIIMath</a>.</p>"
        . $tree->search_and_return_file_contents('footer.html')
        . "</body></html>";
} 



#----------------------------------------------------------------
# sanity_check
# inputs:
#    TEXT = input string
#    MAX_LENGTH = maximum length
#    FORBID_LESS_THAN 
#         to disallow HTML tags
#         0 = allow them
#         1 = silently change them to &lt;
#         2 = strip them out, and produce an error message
#    ALLOW_BACKTICKS = 0,1; to avoid inadvertently doing shell escapes
# output: (out,msg)
#    out = same as input if it's sane; or a sanitized form; or a null string
#    msg = error message describing why insane, or a null string if sane; html formatted, with
#				<p> tags
#----------------------------------------------------------------
sub sanity_check {
  my %args = (
    TEXT=>"",
    MAX_LENGTH=>2000,
    FORBID_LESS_THAN=>2,
    ALLOW_BACKTICKS=>0,
    @_
  );
  my $text = $args{TEXT};
  my $msg = "";
  if ((length $text)>$args{MAX_LENGTH}) {return ("","Error: input was too long")}
  if ($args{FORBID_LESS_THAN}==1) {
    if ($text =~ m/\</) {
      $text =~ s/\</\&lt\;/g;
    }
  }
  if ($args{FORBID_LESS_THAN}==2) {
    if ($text =~ m/\</) {
      $msg = $msg."<p>Illegal &lt; signs stripped from input</p>\n";
      $text =~ s/\<//g;
    }
  }
  if (!$args{ALLOW_BACKTICKS}) {
    if ($text =~ m/\`/) {
      $msg = $msg."<p>Illegal symbols stripped from input</p>\n";
      $text =~ s/\`//g;
    }
  }
  return ($text,$msg);
}


sub super_and_sub {
  my $text = shift;
    $text =~ s/\^\{([^\}]+)\}/\<sup\>$1\<\/sup\>/g;
    $text =~ s/\_\{([^\}]+)\}/\<sub\>$1\<\/sub\>/g;
    $text =~ s/i\{([^\}]+)\}/\<i\>$1\<\/i\>/g;
    $text =~ s/b\{([^\}]+)\}/\<b\>$1\<\/b\>/g;
    $text =~ s/e\{([^\}]+)\}/\&$1;/g;
    # We don't do i{} here, because it should be omitted unless we're at depth 3.
    return $text;
}

sub asciimath_js_code {
return <<'JS';
<script>mathcolor="Black"</script>
<script>
//--------------- begin javascript code -------------------
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
    if (st!=null) eval(String(st).replace(/function anonymous\(\)/,""));
  }
}


function render(inputId,outputId,variables) {
  var str = document.getElementById(inputId).value;
  var outnode = document.getElementById(outputId);
  var n = outnode.childNodes.length;
  for (var i=0; i<n; i++)
    outnode.removeChild(outnode.firstChild);
  str = str.replace(/\*\*/g,"^"); // Spotter allows fortran-style use of ** for exponentiation
  var cooked = new Array();
  for (var i=0; i<variables.length; i++) {
   var u = variables[i];
   var v = format_variable_name(u);
   if (u!=v) str = str.replace(new RegExp(u,"g"),v);
  }
  if (AMisMathMLavailable() != null) {
    str = '--This feature is not available in your browser.--';
  }
  else  {
    str = "`"+str+"`";
  }
  outnode.appendChild(document.createTextNode(str));
  AMprocessNode(outnode);
}

// exmaples: alpha1 -> alpha_(1) , mus -> mu_(s) , Ftotal -> F_(total)
// problems: operators like eq will get treated as variables, rendered as e_(q)
function format_variable_name(x) {
  y = x.replace(/^(alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)(.*)$/g,"$1_($2)");
  if (y!=x) return y;
  y = x.replace(/^(.)(.+)$/,"$1_($2)");
  return y;
}
//--------------- end javascript code -------------------
</script>
JS
}


return 1;
