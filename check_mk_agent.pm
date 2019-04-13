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
use Scalar::Util::Numeric qw(isnum isint isfloat);
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
	die "No answer from Check_Mk" if (scalar (@lines) == 0);
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

	my @df_datas = $this->{'sections'}{'df'};
	return  @df_datas;
}

sub check_load() {
	my $this = shift;
	my ($w1, $w5, $w15, $c1, $c5, $c15) = @_;
	$w1 = 0 unless defined $w1;	$w5 = 0 unless defined $w5;	$w15 = 0 unless defined $w15;
	$c1 = 0 unless defined $c1;$c5 = 0 unless defined $c5;$c15 = 0 unless defined $c15;
	my $ret = $OK; my $message = "";

	logD(Dumper($this->{'sections'}{'cpu'}));

	my $load_datas = $this->{'sections'}{'cpu'}[0];

	my ($l1, $l5, $l15, @unused) = split (' ', $load_datas);

	if    ($l1>$c1 || $l5>$c5 || $l15>$c15 ){ $ret = $CRIT;}
	elsif ($l1>$w1 || $l5>$w5 || $l15>$w15 ){ $ret = $WARN;}
#	WARNING - load average: 1.08, 0.63, 0.71|load1=1.080;1.000;2.000;0; load5=0.630;1.000;2.000;0; load15=0.710;1.000;2.000;0;
 	$message = sprintf ("load average %.2f, %.2f, %.2f|load1=%.3f;%.3f;%.3f;0; load5=%.3f;%.3f;%.3f;0; load15=%.3f;%.3f;%.3f;0;", $l1, $l5, $l15, $l1, $w1, $c1, $l5, $w5, $c5, $l15, $w15, $c15);
 	return $ret, $message;
}

sub check_mailq() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";

	my $os = $this->get_os();

	logD("Warning=$w, Critical=$c");
	logD(Dumper($this->{'sections'}{'postfix_mailq'}));
	my ($unused1, $size_deferred, $deferred);
	my ($unused2, $size_active, $unused3, $unused4, $active);
	if ($os eq 'linux') {
		($unused1, $size_deferred, $deferred) = split (' ', $this->{'sections'}{'postfix_mailq'}[0]);
		($unused2, $size_active, $active) = split (' ', $this->{'sections'}{'postfix_mailq'}[1]);
		if  ($active > $c) { $ret = $CRIT;}
		elsif($active > $w) { $ret = $WARN;}
		$message = sprintf ("mailq length is %d|unsent=%d;%d;%d;0", $active, $active, $w, $c);
	} elsif ($os eq 'freebsd') {
		if($this->{'sections'}{'postfix_mailq'}[0] eq 'Mail queue is empty') {
			$active = 0;
			$size_active = 0;
		} else {	# -- 1941 Kbytes in 179 Requests.
			($unused2, $size_active, $unused3, $unused4, $active) = split (' ', $this->{'sections'}{'postfix_mailq'}[0]);
		}
		if  ($active > $c) { $ret = $CRIT;}
		elsif($active > $w) { $ret = $WARN;}
		$message = sprintf ("mailq length is %d KB|unsent=%d;%d;%d;0", $size_active, $active, $w, $c);
	}
 	return $ret, $message;
}

sub check_procs() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";

	logD(Dumper($this->{'sections'}{'ps'}));

	my $proc_count = scalar @{ $this->{'sections'}{'ps'} };
	if  ($proc_count > $c) {$ret = $CRIT;}
	elsif($proc_count > $w) {$ret = $WARN;}
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
sub mem_get_value() {
	my $this = shift;
	my $text = shift;
	my ($label, $value, $unit) = split (/\W+/, $text);
	return $value;
}
sub check_memory_linux() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";
	my $SwapUsed; my $MemUsed; my $Caches; my $PageTables; my $TotalUsed_kb; my $TotalUsed_mb;
	my $TotalMem_kb; my $TotalMem_mb; my $TotalUsed_pc; my $TotalVirt_mb;
	my $PgText = "";

	logD("Warning=$w, Critical=$c");
	logD(Dumper($this->{'sections'}{'mem'}));
	my $MemTotal_t		= $this->{'sections'}{'mem'}[0];
	my $MemFree_t		= $this->{'sections'}{'mem'}[1];
	my $Buffers_t		= $this->{'sections'}{'mem'}[3];
	my $Cached_t		= $this->{'sections'}{'mem'}[4];
	my $SwapTotal_t		= $this->{'sections'}{'mem'}[14];
	my $SwapFree_t		= $this->{'sections'}{'mem'}[15];
	my $PageTables_t	= $this->{'sections'}{'mem'}[25];

# 		my $DebugState = $DB::single;
# 		$DB::single = 1;
	$SwapUsed = $this->mem_get_value ($SwapTotal_t) - $this->mem_get_value ($SwapFree_t);
	$MemUsed = $this->mem_get_value ($MemTotal_t) - $this->mem_get_value ($MemFree_t);
	$Caches = $this->mem_get_value ($Buffers_t) + $this->mem_get_value ($Cached_t);
	$PageTables = $this->mem_get_value ($PageTables_t);
	$TotalUsed_kb = $SwapUsed + $MemUsed - $Caches + $PageTables;
	$TotalUsed_mb = $TotalUsed_kb / 1024;
	$TotalMem_kb = $this->mem_get_value ($MemTotal_t);
	$TotalMem_mb = $TotalMem_kb / 1024;
	$TotalUsed_pc = ($TotalUsed_kb / $TotalMem_kb) * 100;
	$TotalVirt_mb = ($this->mem_get_value ($SwapTotal_t) + $this->mem_get_value ($MemTotal_t)) / 1024;

	if ($PageTables > 0) {
		$PgText = sprintf (" + %.2f Pagetables", $PageTables / 1048576.0);
	}
	if (isfloat($w)) {
		$w = $w * $TotalMem_mb /100;
		$c = $c * $TotalMem_mb /100;
	}
	if  ($TotalUsed_mb > $c) {$ret = $CRIT;}
	elsif($TotalUsed_mb > $w) {$ret = $WARN;}
	$message .= sprintf ("%.2f GB used (%.2f RAM + %.2f SWAP%s, this is %.1f%% of %.2f RAM (%.2f total SWAP)",
		$TotalUsed_mb / 1024, ($MemUsed - $Caches) / 1024, $SwapUsed / 1048576.0,
		$PgText, $TotalUsed_pc, $TotalMem_mb / 1024, $this->mem_get_value ($SwapTotal_t) / 1048576);
	$message .= sprintf("|ramused=%dMB;;;0;%.4f ", ($MemUsed - $Caches) / 1024, $TotalMem_mb);
	$message .= sprintf("swapused=%dMB;;;0;%d ", $SwapUsed / 1024, $this->mem_get_value ($SwapTotal_t) / 1024);
	$message .= sprintf("memused=%.4f;%d;%d;0;%d", $TotalUsed_mb, $w, $c, $TotalVirt_mb);

	return $ret, $message;
}

sub check_memory_freebsd() {
	my $this = shift;
	my ($w, $c) = @_;
	my $ret = $OK; my $message = "";
	my $SwapUsed; my $MemUsed; my $Caches; my $PageTables; my $TotalUsed_kb; my $TotalUsed_mb;
	my $TotalMem_kb; my $TotalMem_mb; my $TotalUsed_pc; my $TotalVirt_mb;
	my $PgText = "";

	my $Cached_t		= $this->{'sections'}{'statgrab_mem'}[0];
	my $MemFree_t		= $this->{'sections'}{'statgrab_mem'}[1];
	my $MemTotal_t		= $this->{'sections'}{'statgrab_mem'}[2];
	my $MemUsed_t		= $this->{'sections'}{'statgrab_mem'}[3];
	my $SwapFree_t		= $this->{'sections'}{'statgrab_mem'}[4];
	my $SwapTotal_t		= $this->{'sections'}{'statgrab_mem'}[5];
	my $SwapUsed_t		= $this->{'sections'}{'statgrab_mem'}[6];

	$SwapUsed = $this->mem_get_value ($SwapTotal_t) - $this->mem_get_value ($SwapFree_t);
	$MemUsed = $this->mem_get_value ($MemTotal_t) - $this->mem_get_value ($MemFree_t);
	$Caches = 0;
	$PageTables = 0;
	$TotalUsed_kb = $SwapUsed + $MemUsed - $Caches + $PageTables;
	$TotalUsed_mb = $TotalUsed_kb / 1024;
	$TotalMem_kb = $this->mem_get_value ($MemTotal_t);
	$TotalMem_mb = $TotalMem_kb / 1024;
	$TotalUsed_pc = ($TotalUsed_kb / $TotalMem_kb) * 100;
	$TotalVirt_mb = ($this->mem_get_value ($SwapTotal_t) + $this->mem_get_value ($MemTotal_t)) / 1024;
	if (isfloat($w)) {
		$w = $w * $TotalMem_mb /100;
		$c = $c * $TotalMem_mb /100;
	}
	if  ($TotalUsed_mb > $c) {$ret = $CRIT;}
	elsif($TotalUsed_mb > $w) {$ret = $WARN;}
	$message .= sprintf ("%.2f GB used (%.2f RAM + %.2f SWAP%s, this is %.1f%% of %.2f RAM (%.2f total SWAP)",
		$TotalUsed_mb / 1024, ($MemUsed - $Caches) / 1024, $SwapUsed / 1048576.0,
		$PgText, $TotalUsed_pc, $TotalMem_mb / 1024, $this->mem_get_value ($SwapTotal_t) / 1048576);
	$message .= sprintf("|ramused=%dMB;;;0;%.4f ", ($MemUsed - $Caches) / 1024, $TotalMem_mb);
	$message .= sprintf("swapused=%dMB;;;0;%d ", $SwapUsed / 1024, $this->mem_get_value ($SwapTotal_t) / 1024);
	$message .= sprintf("memused=%.4f;%d;%d;0;%d", $TotalUsed_mb, $w, $c, $TotalVirt_mb);

	return $ret, $message;
}

sub check_memory() {
	my $this = shift;
	my ($w, $c) = @_;

	my $os = $this->get_os();
	if ($os eq 'linux') {
		return $this->check_memory_linux($w, $c);
	} elsif ($os eq 'freebsd') {
		return $this->check_memory_freebsd($w, $c);
	}
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

sub check_mount() {
	my $this = shift;
	my ($mountpoint, $w, $c) = @_;
	my $ret = $OK; my $message = "";
	my($dev, $type, $total, $used, $avail, $percent, $mnt);

	my @df = @{$this->{'sections'}{'df'}};
	logD(Dumper($this->{'sections'}{'df'}));

	my $found = 0;
	foreach my $line (@df) {
		last if $line =~ /\[df_inodes_start\]/;
		($dev, $type, $total, $used, $avail, $percent, $mnt) = split (/\s+/, $line);
		if ($mnt eq $mountpoint) {
			$found = 1;
			$percent = $used/$total*100;
			if  ($percent > $c) {$ret = $CRIT;}
			elsif($percent > $w) {$ret = $WARN;}
			last;
		}
	}
	if ($found) {
		$percent = $used/$total*100;
		$message .= sprintf ("%.1f%% used (%.2f of %.2f GB), (levels at %.2f/%.2f%%)", $percent, $used/1048576, $total/1048576, $w, $c);
		$message .= sprintf("|%.4fMB;%.1f;%.1f;0;%d", $used/1024, $total*$w/102400, $total*$c/102400, $total/1024 );
	} else {
		$ret = $UNKN;
		$message = "No such filesytem";
	}
	return $ret, $message;
}

sub check_if () {
	my $this = shift;
	my ($interface, $w, $c) = @_;
	my $os = $this->get_os();
	if ($os eq 'linux') {
		return $this->check_if_linux ($interface, $w, $c);
	} elsif ($os eq 'freebsd') {
	}
}

sub check_if_linux() {
	my $this = shift;
	my ($interface, $w, $c) = @_;
	my ($rcvbytes, $rcvpackets, $rcverrs, $rcvdrops, $rcvfifo, $rcvframe, $rcvcompress, $rcvmulticast,
		$trbytes, $trpackets, $trerrs, $trdrops, $trfifo, $trcolls, $trcarrier, $trcompress);
	my ($speed, $duplex, $up, $mac);
	my $ret = $OK; my $message = "";

	logD(Dumper($this->{'sections'}{'lnx_if:sep(58)'}));


	my @lines = @{$this->{'sections'}{'lnx_if:sep(58)'}};
	my $collectstate  = 0;
	for (my $i=0; $i < scalar @lines; $i++) {
		my $line = $lines[$i];
		next if $line =~ /^$/;
		if ($collectstate == 0) {
			if ($line =~ /^\[(.*)\]/) {
				$collectstate = 1;
				$i--;
				next;
			}
			my ($intf, $values) = split (/:/, $line);
			if ($intf eq $interface) {
				$values =~ s/^\s+//;
				($rcvbytes, $rcvpackets, $rcverrs, $rcvdrops, $rcvfifo, $rcvframe, $rcvcompress, $rcvmulticast,
					$trbytes, $trpackets, $trerrs, $trdrops, $trfifo, $trcolls, $trcarrier, $trcompress) = split (/\s+/, $values);
			}

		} elsif ($collectstate == 1) {
			if ($line =~ /^\[(.*)\]/) {
				if ($1 eq $interface) {
					$collectstate = 2;
				}
			}
		} elsif ($collectstate == 2) {
			last if ($line =~ /^\[(.*)\]/);
			my ($key, $value) = split (':', $line, 2);
			$value =~ s/^\s+//;
			$speed  = $value if ($key =~ /\tSpeed/);
			$duplex  = $value if ($key =~ /\tDuplex/);
			$up  = $value if ($key =~ /\tLink detected/);
			$mac = $value if ($key =~ /\tAddress/);
		}
	}
	if ($up =~ /yes/) {
		$up = "on";
	} else {
		$up = "down";
		$ret = $CRIT;
	}
	my $inerr = ($rcverrs + $rcvdrops)/$rcvpackets;
	my $outerr = ($trerrs + $trdrops)/$trpackets;
	if (($inerr > $c) || ($outerr > $c)) {$ret = $CRIT;}
	if (($inerr > $w) || ($outerr > $w)) {$ret = $WARN;}

	$message .= sprintf ("[000] (%s) MAC: %s, %s, in: %.2f kB/s, out: %.2f kB/s", $up, $mac, $speed, $rcvbytes/1024, $trbytes/1024);
	$message .= sprintf("|in=%.4f;;;0;125000000 indisc=%d;;;; inerr=%d;%.2f;%.2f;; out=%.4f;;;0;125000000", $rcvbytes, $rcvdrops, $inerr, $w, $c, $trbytes);

	return $ret, $message;
}

sub check_diskio () {
	my $this = shift;

	my $DebugState = $DB::single;
	$DB::single = 1;
	my $os = $this->get_os();
	if ($os eq 'linux') {
		return $this->check_diskio_linux();
	} elsif ($os eq 'freebsd') {
		return $this->check_diskio_freebsd();
	}
}

sub check_diskio_linux() {
	my $this = shift;
	my $ret = $OK; my $message = "";
	my ($major, $minor, $devname,
		$readcompl, $readmerg, $readsect, $readtime,
		$writecompl, $writemerg, $writesect, $writetime,
		$iocount, $iotime, $ioweithtedtime);

	my @lines = @{$this->{'sections'}{'diskstat'}};
	logD(Dumper(@lines));

	for (my $i=1; $i < scalar @lines; $i++) {	# start at 1, skip timestamp
		my $line = $lines[$i];
		$line =~ s/^\s+//;
		last if $line =~ /dmsetup_info/;
		($major, $minor, $devname,
			$readcompl, $readmerg, $readsect, $readtime,
			$writecompl, $writemerg, $writesect, $writetime,
			$iocount, $iotime, $ioweithtedtime) = split (/\s+/, $line, 14);
		if($devname !~ /[0-9]+/) {
			last;
		}
	}
	my $totalreadpersec = ($readcompl+$readmerg)/$readtime*1000;
	my $totalwritepersec = ($writecompl+$writemerg)/$writetime*1000;

	my $iorate = ( $readcompl+$readmerg+$writecompl+$writemerg)/$iotime;
	$message .= sprintf("%.2f kB/s read, %.2f kB/s write, IOs %.2f/sec", $totalreadpersec/1024, $totalwritepersec/1024, $iorate);
	$message .= sprintf("|read=%.4f;;;; write=%.4f", $totalreadpersec, $totalwritepersec);
	return $ret, $message;
}

sub check_diskio_freebsd() {
	my $this = shift;
	my $ret = $OK; my $message = "";
	my $read = 0;
	my $written = 0;

	my @lines = @{$this->{'sections'}{'statgrab_disk'}};

	foreach my $line (@lines) {
		if ($line =~ /read_bytes/) {
			my ($key, $value) = split (/\s/, $line);
			$read += $value;
		}
		if ($line =~ /write_bytes/) {
			my ($key, $value) = split (/\s/, $line);
			$written += $value;
		}
	}



	return $ret, $message;
}

sub check_zfs_mem() {
	my $this = shift;
	my $ret = $OK; my $message = "";

	my @lines = @{$this->{'sections'}{'zfs_memory'}};
	logD(Dumper($this->{'sections'}{'zfs_memory'}));

	my ($unused0, $physical_ram)	= split (' ', $lines[0]);
	my ($unused1, $free_memory)	= split (' ', $lines[1]);
	my ($unused2, $arc_size)		= split (' ', $lines[2]);
	my ($unused3, $target_size)	= split (' ', $lines[3]);
	my ($unused4, $zfs_arc_min)	= split (' ', $lines[4]);
	my ($unused5, $zfs_arc_max)	= split (' ', $lines[5]);
	my ($unused6, $mru_percent)	= split (' ', $lines[6]);
	my ($unused7, $mfu_percent)	= split (' ', $lines[7]);
	
	$message .= sprintf ("Arc size %.2d MB", $arc_size / 1048576.0);
	$message .= sprintf("|arc size=%dMB;0;0;%d;%d", $arc_size / 1048576.0, $zfs_arc_min / 1048576,  $zfs_arc_max / 1048576);
	
	return $ret, $message;
}
















sub logD {
	my ($msg) = @_;
	print STDERR "DEBUG: $msg\n" if $DEBUG;
}


1;
