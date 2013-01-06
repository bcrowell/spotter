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
use Tint 'tint';

our $cgi;
my $debugging_is_active = 0;
our $debugging_output = '';
our $homepath = '';
our $title = 'Spotter';

sub HTTPHeader {
        my $cookie_list = shift;
        return $cgi->header(-type=>'text/html',-cookie=>$cookie_list,-expires=>'now');
	        # the 'expires' part refers to cache control, not cookies.
	#print "Pragma: no-cache\nCache-control: private\nContent-Type: text/html\n\n";
}


sub HeaderHTML
{
  my ($spotter_js_dir) = @_; # title not actually used
  return tint('boilerplate.header_html','homepath'=>$homepath,'spotter_js_dir'=>$spotter_js_dir)
} 

sub activate_debugging_output {
  $debugging_is_active = 1;
}

sub debugging_output {
  if (!$debugging_is_active) {return}
  my $msg = shift;
  $debugging_output = $debugging_output . "<p>--- $msg</p>\n";
}

sub accumulated_debugging_output {
  return $debugging_output;
}

sub BannerHTML
{
  my $tree = shift;
  my $result =  $tree->search_and_return_file_contents('banner.html');
  if ($result ne '') {return $result}
  return tint('boilerplate.default_banner_html');
}

sub FooterHTML
{
  my $tree = shift;
  return tint('boilerplate.footer_html','footer_file'=>$tree->search_and_return_file_contents('footer.html'));
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
  my $am = tint('boilerplate.asciimath_js_code');
  return "<script>mathcolor=\"Black\"</script><script>$am</script>";
}


return 1;
