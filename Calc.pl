#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2001-2013 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
# The software is copyrighted, and you must agree to one of
# these licenses in order to have permission to copy it. The full
# text of both licenses is given in the file titled Copying.
#
# Command-line options:
#   -e expression                noninteractive use
#   -i infile
#   -o outfile
#   -c                           clear vars after each line of input
#   -d                           debugging mode
#   -p                           print back each line of input
#   -h                           html output mode
#   -x                           load some useful physics symbols
#   -s                           If the expression input using -e was a fully evaluated numerical expression, output the number of sig figs. Otherwise output -1.
#   -u                           don't allow units in expressions
#
# Type control-D to exit.
#
# Use the symbol ~ to get the result of the last calculation.
#----------------------------------------------------------------

use strict;

use FindBin;
use lib $FindBin::RealBin;
   # RealBin follows symbolic links, as opposed to Bin, which doesn't.

use Spotter;
use Parse;
use ParseHeuristics;
use Eval;
use Rational;
use Units;
use Measurement;
use Math::Complex;
use Math::Trig;
use Message;
use Getopt::Std;
use Expression; # currently only used in one place; should be used consistently

my %cons_hash = %Spotter::standard_cons_hash;

my ($tokens_ref,$errors_ref,$rpn_ref);
my %vars = ();
my $line_num = 1;

#------------------------------------------------
my %options = ();
getopts("pdci:o:e:hxsu",\%options);
foreach my $op ("p","d","i","o","c","e","h","s","u") {
  if (!exists $options{$op}) {$options{$op}="";}
}
#------------------------------------------------

if (!$options{"i"} && !$options{"e"}) {
  print "Spotter Calculator, (c) 2001-2003 Benjamin Crowell. This is free software.\n";
  print "See the file named Copying for copyleft information.\n";
}

if ($options{"i"} ne "") {
  open (INFILE,"<".$options{"i"}) or die "Error opening input file ".$options{"i"};
}
else {
  open (INFILE,"-");
}

if ($options{"o"} ne "") {
  open (OUTFILE,">".$options{"o"}) or die "Error opening output file ".$options{"o"};
}
else {
  open (OUTFILE,">-");
}


my $one_shot = $options{"e"};
my $print_prompts = !($options{"e"} || $options{"i"});
my $debug = $options{"d"};
my $print_input_back_out = $options{"p"};
my $output_mode = "text";
if ($options{"h"} ne "") {$output_mode="html";}

my $units_allowed = 1;
if ($options{'u'}) {
  $units_allowed = 0;
}

if ($debug) {print "output_mode=$output_mode\nunits_allowed=$units_allowed\n";}


if ($options{'x'}) {
  if (!$units_allowed) {die "options -x and -u are incompatible"}
  foreach my $x(
    ['e','1.60217649 10^-19 C'],
    ['G','6.67428 10^-11 N.m2/kg2'],
    ['k','8.9875517873681764 10^9 N.m2/C2'],
    ['kB','1.380650 10^-23 J'],
    ['c','299792458 m/s'],
    ['h','6.62606896 10^-34 J.s'],
    ['hbar','(6.62606896 10^-34 J.s)/(2*3.14159265358979)'],
  ) {
    my ($v,$expression) = ($x->[0],$x->[1]);
    my ($tokens_ref,$errors_ref) = lex(EXPRESSION=>$expression,DEBUG=>0);
    my $back_refs_ref;
    my ($rpn_ref,$errors_ref,$back_refs_ref) = parse(TOKENS=>$tokens_ref);
    my ($result,$errors_ref) = evaluate(RPN=>$rpn_ref, VARIABLES=>\%vars, CONSTANTS=>\%cons_hash,
                                                                DEBUG=>0,BACK_REFS=>$back_refs_ref,PRETTIFY_UNITS=>1);
    $vars{$v} = $result;
    print "setting $v to $result\n";
  }
  delete $cons_hash{'e'};
}

#------------------------------------------------
my $last_result = "";

if ($print_prompts) {print "> ";}


while(1){
    my $line = "";
    if (!$options{"e"}) {
      $line = <INFILE>;
    }
    else {
      $line = $options{"e"};
    }
    if (!$line) {
      if ($print_prompts) {print "\n";}
      last; #<------------ exit from loop
    }
    else {
      if ($print_input_back_out) {print OUTFILE $line;}
    }
    # Get rid of comments:
    my @zzz = split /\#/,$line,2;
    my $line = $zzz[0];
    # Split at semicolons:
    my @cmds = split /\;/,$line;
    
    foreach my $command(@cmds) {
        if (!($command =~ m/^\s*$/)) {
                        my ($lvalue,$expression);
                        
                        if ($command =~ m/\s*([^=\s]*)\s*=\s*([^=]*)\s*/) {
                          $lvalue = $1;
                          $expression = $2;
                          if ($lvalue eq "") {
                                print OUTFILE "Warning: equals sign ignored.\n";
                          }
                        }
                        else {
                          $lvalue = "";
                          $expression = $command;
                        }
                        
                        $expression =~ s/\~/\($last_result\)/g;
                        #print ParseHeuristics::paren_debugging_diagram($expression);
                
                        my @var_names = keys(%vars);
                        my @cons_names = keys %cons_hash;
                        
                        ($tokens_ref,$errors_ref) = 
                          lex(EXPRESSION=>$expression,
                                VARIABLES=>\@var_names, CONSTANTS=>\@cons_names,
                                DEBUG=>0,UNITS_ALLOWED=>$units_allowed);
                        
                        my @tt = @$tokens_ref;
                        
                        if ($debug) {
                                print "tokens = ";
                                foreach my $token(@tt) {
                                  print "'$token' ";
                                }
                                print "\n";
                        }
                        # The following is a kludge -- should just use the
                        # object-oriented interface from the get-go.
                        my $e = Expression->new(EXPR=>$expression,
                                      VAR_NAMES=>\@var_names,OUTPUT_MODE=>'text',
                                      UNITS_ALLOWED=>$units_allowed);
                        $e->parse(); # kludge, forces it to do a check_ambiguities()
                        print $e->format_errors();
                        
                        my $back_refs_ref;
                        ($rpn_ref,$errors_ref,$back_refs_ref) =
                          parse(TOKENS=>$tokens_ref,        
                                        VARIABLES=>\@var_names, CONSTANTS=>\@cons_names,DEBUG=>0,
                                        UNITS_ALLOWED=>$units_allowed);
                        
                        if ($debug) {
                                print "rpn = ";
                                foreach my $token(@$rpn_ref) {
                                  print "'$token' ";
                                }
                                print "\n";
                                my %r = %$back_refs_ref;
                                print "back refs = ";
                                foreach my $j(keys(%r)) {
                                  print $j."=>". $r{$j}. " ";
                                }
                                print "\n";
                                if ($e->is_nonanalytic()) {
                                    print "nonanalytic\n";
                                }
                                else {
                                    print "analytic\n";
                                }
                        }
                        print OUTFILE format_errors(ERRORS_REF=>$errors_ref,TOKENS_REF=>$tokens_ref,
                                                           OUTPUT_MODE=>$output_mode);
                        
                        my $result;
                        unless (@$errors_ref) {
                          ($result,$errors_ref) 
                          = evaluate(RPN=>$rpn_ref, VARIABLES=>\%vars, CONSTANTS=>\%cons_hash,
                                                                DEBUG=>0,BACK_REFS=>$back_refs_ref,PRETTIFY_UNITS=>1);
                          print OUTFILE format_errors(ERRORS_REF=>$errors_ref,TOKENS_REF=>$tokens_ref,OUTPUT_MODE=>$output_mode);
                        }

                        #print "ref=".ref($result)."\n";
                        
                        if ($options{"s"} ne "") {
                          print Parse::count_sig_figs($expression);
                        } # end if -s
                        else { 
                          print OUTFILE "    ";
                          if ($lvalue ne "") {
                            $vars{$lvalue} = $result;
                            print OUTFILE "$lvalue = $result";
                            if (exists $cons_hash{$lvalue}) {
                                  delete($cons_hash{$lvalue});
                            }
                          }
                          else {
                            print OUTFILE $result;
                          }
                        } # end if not -s
                        print OUTFILE "\n";
                        $last_result = $result;
                        
                        if ($debug && !Spotter::is_null_string($result) && ref($result) eq "Measurement") {
                                #print "ref=".ref($result)."\n";
                                print "atomized=".atomize($result,\%Spotter::standard_units) . "\n";
                        }
                } # end if not an empty command
        } # end loop over commands on one line separated by semicolons
        ++$line_num;
        if ($print_prompts) {print "> ";}
        if ($one_shot) {last;}
        if ($options{"c"} ne "") {%vars = ();}
}
