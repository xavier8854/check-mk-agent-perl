#!/usr/bin/perl -w

###########################################################################
# $Id: cmk_plugin.pl, v0.9 r1 10/10/2018 08:42:43 CEST XH Exp $
#
# Copyright 2018 Xavier Humbert <xavier.humbert@ac-nancy-metz.fr>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following disclaimer
#   in the documentation and/or other materials provided with the
#   distribution.
# * Neither the name of the Academie de Nancy Metz nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
###########################################################################

use strict;
use File::Basename;
use Nagios::Plugin;
use lib '.';
use check_mk_agent;

#####
## PROTOS
#####

#####
## CONSTANTS
#####
my $PROGNAME = basename($0);
my $VERSION = '0.9a1';
my $TIMEOUT = 9;

#####
## VARIABLES
#####
my $rc=0;
my $w1 = 1; my $w5 = 1; my $w15 = 1;
my $c1 = 5; my $c5 = 5; my $c15 = 5;
my $DEBUG = 0;
my $verbose = 0;

#####
## MAIN
#####

my $dir = dirname($0);
cd $dir || die "No such directory $dir";

my $np = Nagios::Plugin->new(
	version => $VERSION,
	blurb => 'Plugin to check load on remote host',
	usage => "Usage: %s [ -v|--verbose ]  -H <host> [-p <port> (def. 6556)][-t <timeout>] [ -c|--critical=<thresholds (def. 5,5,5)> ] [ -w|--warning=<thresholds> (def. 1,1,1]",
	timeout => $TIMEOUT+1
);
$np->add_arg (
	spec => 'debug|d',
	help => 'Debug level',
	default => 0,
);
$np->add_arg (
	spec => 'H=s',
	help => 'Address of the remote host.',
	default => 'localhost',
);
$np->add_arg (
	spec => 'p=i',
	help => 'port',
	default => 6556,
);
$np->add_arg (
	spec => 'w=s',
	help => 'Warning threshold',
	default => '1,1,1',
	label => 'STRING'
);
$np->add_arg (
	spec => 'c=s',
	help => 'Critical threshold',
	default => '5,5,5',
	label => 'STRING'
);

$np->getopts;

my $warn_s = $np->opts->get('w');
my $crit_s = $np->opts->get('c');
($w1, $w5, $w15) = split (',', $warn_s);
($c1, $c5, $c15) = split (',', $crit_s);

my $host = $np->opts->get('H');
my $port = $np->opts->get('p');
$DEBUG = $np->opts->get('debug');
$verbose = $np->opts->verbose;

my $checker = check_mk_agent->new(PeerAddr => $host, PeerPort => $port, debug => $DEBUG);
my ($status, $message) = $checker->check_load($w1, $w5, $w15, $c1, $c5, $c15);

$np->nagios_exit($status, $message );

#######################################################################

#####
## FUNCTIONS
#####




=pod


=cut
