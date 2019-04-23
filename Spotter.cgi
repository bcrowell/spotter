#!/usr/bin/perl

#----------------------------------------------------------------
# Copyright (c) 2001 Benjamin Crowell, all rights reserved.
#
# This software is available under two different licenses: 
#  version 2 of the GPL, or
#  the Artistic License. 
#
#----------------------------------------------------------------

use FindBin qw( $RealBin );
use lib $RealBin;


use strict;
use WebInterface;
WebInterface->new()->run();
