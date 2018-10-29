###########################################################################
# $Id: check_mk_agent.pl, v0.9 r1 10/10/2018 08:42:43 CEST XH Exp $
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

package check_mk_agent;
our $VERSION = '0.9a1';
use strict;
use warnings;
use Data::Dumper;
use Data::Dumper;
use IO::Socket;
#~ use DB;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK );
@ISA = qw(Exporter);
@EXPORT_OK = qw(DEBUG logD);  # symbols to export on request
#
# Protos
#


#
# CONSTANTS
#
our $DEBUG = 0;
our $OK = 0;
our $WARN = 1;
our $CRIT = 2;
our $UNKN = 3;

#
# Variables
#

sub new () {
    my ($class, %args) = @_;
	if ( defined($args{'debug'}) ) {
		$DEBUG = $args{'debug'};
	}
    my $this = bless \%args, $class;
    my $sock = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $args{'PeerAddr'}, PeerPort => $args{'PeerPort'})
	   or die "connect failed: $!";
	my @lines = <$sock>;
	close $sock;
	$this->{'lines'} = \@lines;
	$this->readSections();
	return $this;
}

sub readSections () {
	my $this = shift;
	my $lineref = $this->{'lines'};
	my $curSection = "";
	my $line;
	my %sections;

	foreach $line (@$lineref) {
		if ($line =~ /\<\<\<(.*)\>\>\>/) {
			$curSection = $1;
			next;
		}
		chomp($line);
		push @{$sections{$curSection}}, $line;

	}
	$this->{'sections'}= \%sections;
	undef $this->{'lines'};
}

#=========================== Checks =============================================================

sub get_os () {
	my $this = shift;
	my ($unused, $os) = split (/\W+/, $this->{'sections'}{'check_mk'}[1]);
	return $os;
}

sub check_df() {
	my $this = shift;
	my ($w, $c) = @_;
	$w = 0 unless defined $w;
	$c = 0 unless defined $c;
	my $ret = "";
	my $status = 'OK';

	my @df_datas = $this->{'sections'}{'df'};
	return  @df_datas;
}

sub check_load() {
	my $this = shift;
	my ($w1, $w5, $w15, $c1, $c5, $c15) = @_;
	$w1 = 0 unless defined $w1;	$w5 = 0 unless defined $w5;	$w15 = 0 unless defined $w15;
	$c1 = 0 unless defined $c1;$c5 = 0 unless defined $c5;$c15 = 0 unless defined $c15;
	my $ret = $OK; my $message = "";
	my $status = 'OK';

	logD(Dumper($this->{'sections'}{'cpu'}));

	my $load_datas = $this->{'sections'}{'cpu'}[0];
	my ($l1, $l5, $l15, @unused) = split (' ', $load_datas);

	if    ($l1>$c1 || $l5>$c5 || $l15>$c15 ){ $status = "CRITICAL"; $ret = $CRIT;}
	elsif ($l1>$w1 || $l5>$w5 || $l15>$w15 ){ $status = "WARNING"; $ret = $WARN;}
#	WARNING - load average: 1.08, 0.63, 0.71|load1=1.080;1.000;2.000;0; load5=0.630;1.000;2.000;0; load15=0.710;1.000;2.000;0;
 	$message = sprintf ("load average %.2f, %.2f, %.2f|load1=%.3f;%.3f;%.3f;0; load5=%.3f;%.3f;%.3f;0; load15=%.3f;%.3f;%.3f;0;", $l1, $l5, $l15, $l1, $w1, $c1, $l5, $w5, $c5, $l15, $w15, $c15);
 	return $ret, $message;
}

sub check_mailq() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";
	my $status = 'OK';

	my $DebugState = $DB::single;
	$DB::single = 1;
	my $os = $this->get_os();
	
	logD("Warning=$w, Critical=$c");
	logD(Dumper($this->{'sections'}{'postfix_mailq'}));
	my ($unused1, $size_deferred, $deferred);
	my ($unused2, $size_active, $active);
	if ($os eq 'linux') {
		($unused1, $size_deferred, $deferred) = split (' ', $this->{'sections'}{'postfix_mailq'}[0]);
		($unused2, $size_active, $active) = split (' ', $this->{'sections'}{'postfix_mailq'}[1]);
		if  ($active > $c) { $status = "CRITICAL"; $ret = $CRIT;}
		elsif($active > $w) { $status = "WARNING"; $ret = $WARN;}
		$message = sprintf ("mailq length is %d|unsent=%d;%d;%d;0", $active, $active, $w, $c);
	} elsif ($os eq 'freebsd') {
		if($this->{'sections'}{'postfix_mailq'}[0] eq 'Mail queue is empty') {
			$active = 0;
		} else {
			($unused2, $size_active, $active) = split (' ', $this->{'sections'}{'postfix_mailq'}[0]);
		}
		if  ($active > $c) { $status = "CRITICAL"; $ret = $CRIT;}
		elsif($active > $w) { $status = "WARNING"; $ret = $WARN;}
		
		$message = sprintf ("mailq length is %d|unsent=%d;%d;%d;0", $active, $active, $w, $c);
	}
 	return $ret, $message;
}

sub check_procs() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";
	my $status = 'OK';

	logD(Dumper($this->{'sections'}{'ps'}));

	my $proc_count = scalar @{ $this->{'sections'}{'ps'} };
	if  ($proc_count > $c) { $status = "CRITICAL"; $ret = $CRIT;}
	elsif($proc_count > $w) { $status = "WARNING"; $ret = $WARN;}
	$message = sprintf ("%d processes | procs=%d;%s;%s;0;", $proc_count, $proc_count, $w==1E9?'':$w, $c==1E9?'':$c);
 	return $ret, $message;
}

sub get_info() {
	my $this = shift;
	my $ret = $OK; my $message = "";

	my $info_data = $this->{'sections'}{'check_mk'};
	foreach my $msg (@$info_data) {
		$message .= sprintf ("%s\n", $msg);
	}
	return $ret, $message;
}

sub check_memory() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";
	my $status = 'OK';
	my $label; my $point;
	my $unit;
	my $MemTotal; my $MemFree; my $SwapTotal; my $SwapFree, my $PageTables; my $MemCache;
	my $Mapped; my $CommitedAs;
	my $MemTotalTotalUsed, my $MemUsed; my $RAMUsed; my $SwapUsed;

	my $DebugState = $DB::single;
	$DB::single = 1;
	my $os = $this->get_os();
	
	logD("Warning=$w, Critical=$c");
	if ($os eq 'linux') {
		logD(Dumper($this->{'sections'}{'mem'}));
		my $MemTotal_t		= $this->{'sections'}{'mem'}[0];
		my $MemFree_t		= $this->{'sections'}{'mem'}[1];
		my $MemAvailable_t	= $this->{'sections'}{'mem'}[2];
		my $Buffers_t		= $this->{'sections'}{'mem'}[3];
		my $Cached_t		= $this->{'sections'}{'mem'}[4];
		my $SwapCached_t	= $this->{'sections'}{'mem'}[5];
		my $Active_t		= $this->{'sections'}{'mem'}[6];
		my $Inactive_t		= $this->{'sections'}{'mem'}[7];
		my $SwapTotal_t		= $this->{'sections'}{'mem'}[14];
		my $SwapFree_t		= $this->{'sections'}{'mem'}[15];
		my $Mapped_t		= $this->{'sections'}{'mem'}[19];
		my $PageTables_t	= $this->{'sections'}{'mem'}[25];
		my $CommitedAs_t	= $this->{'sections'}{'mem'}[30];
	
		($label, $MemTotal, $unit)		= split (/\W+/,  $MemTotal_t);
		($label, $MemFree, $unit)		= split (/\W+/,  $MemFree_t);
		($label, $SwapTotal, $unit)		= split (/\W+/,  $SwapTotal_t);
		($label, $SwapFree, $unit)		= split (/\W+/,  $SwapFree_t);
		($label, $Mapped, $unit)		= split (/\W+/,  $Mapped_t);
		($label, $PageTables, $unit)	= split (/\W+/,  $PageTables_t);
		($label, $CommitedAs, $unit)	= split (/\W+/,  $CommitedAs_t);
	
		$MemTotal /= 1024;
		$MemFree /= 1024;
		$PageTables /= 1024;
		$SwapTotal /= 1024;
		$SwapFree /= 1024;
		$RAMUsed = $MemTotal - $MemFree;
		$SwapUsed = $SwapTotal - $SwapFree;
		$MemTotalTotalUsed = $RAMUsed + $SwapUsed + $PageTables;
	
		if  ($MemTotalTotalUsed > $c) { $status = "CRITICAL"; $ret = $CRIT;}
		elsif($MemTotalTotalUsed > $w) { $status = "WARNING"; $ret = $WARN;}
		$message .= sprintf ("%d MB used (%d RAM + %d SWAP + %d PageTables, this is %.1f%% of %d (%.2f total SWAP))", $MemTotalTotalUsed, $RAMUsed, $SwapUsed, $PageTables, $RAMUsed/$MemTotal*100, $MemTotal, $SwapTotal );
		$message .= sprintf("|ramused=%dMB;;;0;%.4f ", $RAMUsed, $MemTotal);
		$message .= sprintf("swapused=%dMB;;;0;%d ", $SwapUsed, $SwapTotal );
		$message .= sprintf("memused=%.4f;%d;%d;0;%d", $MemTotalTotalUsed, $w, $c, $MemTotal+$SwapTotal);
	#	OK - 0.71 GB used (0.69 RAM + 0.01 SWAP + 0.01 Pagetables, this is 39.3% of 1.80 RAM (3.91 total SWAP)), 0.0 mapped, 0.9 committed, 0.1 shared
	#	ramused=705MB;;;0;1840.34375 swapused=9MB;;;0;4003 memused=723.1796875MB;2760;3680;0;5844.339844 mapped=38MB;;;; committed_as=957MB;;;; pagetables=8.3515625MB;;;; shared=111MB;;;;
	} elsif ($os eq 'freebsd') {
		logD(Dumper($this->{'sections'}{'statgrab_mem'}));
		#~ 'mem.cache 0',
		#~ 'mem.free 5437435904',
		#~ 'mem.total 16654921728',
		#~ 'mem.used 11217485824',
		#~ 'swap.free 22315388928',
		#~ 'swap.total 23622320128',
		#~ 'swap.used 1306931200'
		my $MemCache_t		= $this->{'sections'}{'statgrab_mem'}[0];
		my $MemFree_t		= $this->{'sections'}{'statgrab_mem'}[1];
		my $MemTotal_t		= $this->{'sections'}{'statgrab_mem'}[1];
		my $MemUsed_t		= $this->{'sections'}{'statgrab_mem'}[3];
		my $SwapFree_t		= $this->{'sections'}{'statgrab_mem'}[4];
		my $SwapTotal_t		= $this->{'sections'}{'statgrab_mem'}[5];
		my $SwapUsed_t		= $this->{'sections'}{'statgrab_mem'}[6];
		($label, $point, $MemCache)		= split (/\W+/,  $MemCache_t);
		($label, $point, $MemFree)		= split (/\W+/,  $MemFree_t);
		($label, $point, $MemTotal)		= split (/\W+/,  $MemTotal_t);
		($label, $point, $MemUsed)		= split (/\W+/,  $MemUsed_t);
		($label, $point, $SwapFree)		= split (/\W+/,  $SwapFree_t);
		($label, $point, $SwapTotal)	= split (/\W+/,  $SwapTotal_t);
		($label, $point, $SwapUsed)		= split (/\W+/,  $SwapUsed_t);
		$MemCache /= 1024; $MemFree /= 1024; $MemTotal /= 1024; $MemUsed /= 1024;
		$SwapFree /= 1024; $SwapTotal /= 1024; $SwapUsed /= 1024;
		$MemTotalTotalUsed = $MemUsed + $SwapUsed + $MemCache;
		$MemTotal = $MemTotal + $SwapTotal;
		if  ($MemTotalTotalUsed > $c) { $status = "CRITICAL"; $ret = $CRIT;}
		elsif($MemTotalTotalUsed > $w) { $status = "WARNING"; $ret = $WARN;}
		$message .= sprintf ("%d MB used (%d RAM + %d SWAP + %d Cache, this is %.1f%% of %d (%.2f total SWAP))",
			$MemTotalTotalUsed, $MemUsed, $SwapUsed, $MemCache, $MemTotalTotalUsed/$MemTotal*100,
			$MemTotalTotalUsed, $SwapTotal );
	#	ramused=705MB;;;0;1840.34375 swapused=9MB;;;0;4003 memused=723.1796875MB;2760;3680;0;5844.339844 mapped=38MB;;;; committed_as=957MB;;;; pagetables=8.3515625MB;;;; shared=111MB;;;;
		$message .= sprintf("|ramused=%d;;;0;%d", $MemUsed, $MemTotal);
		$message .= sprintf(" swapused=%d;;;0;%d", $SwapUsed, $SwapTotal);
		$message .= sprintf(" memused=%d;%d;%d;0;%d", $MemTotalTotalUsed, $w, $c, $MemTotal);
	}
 	return $ret, $message;
}

sub check_uptime(){
	my $this = shift;
	my $ret = $OK; my $message = "";

	logD(Dumper($this->{'sections'}{'uptime'}));

	my @info_data = $this->{'sections'}{'uptime'}[0];
	logD (Dumper($info_data[0]));
	my($uptime, $idle) = split (' ', $info_data[0]);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($uptime);
	$message .= sprintf ("%s|uptime=%d idle=%.2d", "$yday days $hour hours $min minutes $sec seconds", $uptime, $idle);
	return $ret, $message;
}




















sub logD {
	my ($msg) = @_;
	print STDERR "DEBUG: $msg\n" if $DEBUG;
}


1;
