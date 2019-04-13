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
