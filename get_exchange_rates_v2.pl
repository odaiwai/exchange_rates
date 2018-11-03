#!/usr/bin/perl
use strict;
use warnings;

# script to get exchange rates
my $start_date = "1219000014";
#my $start_date = "1201000013";
my $end_date = `date +%m-%d-%Y`;
my $date;
my $timestamp = `date -j $start_date +%s`;
my $now = `date +%s`;
my $baseurl = "http://www.exchange-rates.org/Rate";
my %rates;
while ($timestamp <= $now ) {
	$date = `date -jf "%s" $timestamp  +%m-%d-%Y`;
	chomp $date;
	$rates{$timestamp} = &get_rate("AUD", "HKD", $date);
	print "$date: AUD-HKD = $rates{$timestamp}\n";
	$timestamp += 86400; # increment by one day
}

foreach my $time (sort keys %rates) {
	if (exists($rates{$time})) {
		$date = `date -jf "%s" $time  +%d-%m-%Y`;
		chomp $date;
		print "$date, $rates{$time}\n";
	}
}

## Subroutines
sub get_rate {
	my ($cur1, $cur2, $date) = @_;
	print "Looking for $baseurl/$cur1/$cur2/$date...\n";
	my @file = `curl $baseurl/$cur1/$cur2/$date`;
	#my @file = `cat rates_test.html`;
	foreach my $line (@file) {
		chomp $line;
		#print "$line\n";
		# the line we want looks like this:, and it's the "convert a million of $cur1 to $cur2" line
		# <span id="ctl00_M_grid_ctl05_lblResult">96,473.57 EUR</span>
		if ( $line =~ /\<span id\=\"ctl00_M_grid_ctl05_lblResult\"\>([0-9,.]+) [A-Z]+\<\/span\>/){
			my $rate = ($1);
			$rate =~ s/,//g;
			return $rate / 1000000;
			#print "$line\n";
			#print "Rate for $cur1 to $cur2 is $rate.\n";
		}
	}
}
