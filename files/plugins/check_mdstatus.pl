#!/usr/bin/perl -w
### vi: set ts=4 sw=4 si ai: 

use strict;

my $mdadm = "/sbin/mdadm --monitor --scan --oneshot --config=paritions --alert='/bin/echo'";
my $ignore_states = "NewArray";
my $critical_states = "DegradedArray";
my $warning_states = "FailSpare";
my %return_codes = (
	'UNKNOWN' 	=> 	'-1',
	'OK' 		=> 	'0',
	'WARNING' 	=> 	'1',
	'CRITICAL' 	=> 	'2',
);

my @output = map { chomp; $_ } grep { $ignore_states ? ! /$ignore_states/ : 1 } `$mdadm`;
my @warning = grep { /$warning_states/ } @output;
my @critical = grep { /$critical_states/ } @output;
my @unknown = grep { !/$warning_states|$critical_states/ } @output;

if (@critical) {
	print "MDSTATUS CRITICAL " . ( join " ", @critical ) . "\n";
	exit $return_codes{'CRITICAL'};
}
elsif (@warning) {
	print "MDSTATUS WARNING " . ( join " ", @warning ) . "\n";
	exit $return_codes{'WARNING'};
}
elsif (@unknown) {
	print "MDSTATUS UNKNOWN " . ( join " ", @unknown ) . "\n";
	exit $return_codes{'UNKNOWN'};
}
else {
	print "MDSTATUS OK\n";
	exit $return_codes{'OK'};
}

