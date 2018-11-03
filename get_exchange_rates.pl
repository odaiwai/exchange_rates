#!/usr/bin/perl
use strict;
use warnings;

# script to get exchange rates
my @currencies=("HKD", "EUR", "ILS");
my $usedate=shift @ARGV;
my $date;
if ( !$usedate ) {
	$date = `date +%m-%d-%Y`;
} else {
	$date = $usedate;
}
my $baseurl = "http://www.exchange-rates.org/Rate";
my %rates;

foreach my $cur1 (@currencies) {
	foreach my $cur2 (@currencies) {
		if ($cur1 eq $cur2) {
			$rates{$cur1.$cur2}=1.0;
		} else {
			print "Looking for $baseurl/$cur1/$cur2/$date...\n";
			my @file = `curl $baseurl/$cur1/$cur2/$date`;
			#my @file = `cat rates_test.html`;
			foreach my $line (@file) {
				chomp $line;
				#print "$line\n";
				# <span id="ctl00_M_grid_ctl05_lblResult">96,473.57 EUR</span>
				if ( $line =~ /\<span id\=\"ctl00_M_grid_ctl05_lblResult\"\>([0-9,.]+) [A-Z]+\<\/span\>/){
					my $rate = ($1);
					$rate =~ s/,//g;
					$rates{$cur1.$cur2} = $rate / 1000000;
					print "$line\n";
					print "Rate for $cur1 to $cur2 is $rate.\n";
				}
			}
		}
	}
}

foreach my $cur1 (@currencies) {
	foreach my $cur2 (@currencies) {
		print "$cur1 -> $cur2 = $rates{$cur1.$cur2}\n";
	}
} 
print "$date, $rates{'HKDEUR'},  $rates{'EURHKD'},  $rates{'ILSHKD'},  $rates{'HKDILS'},  $rates{'ILSEUR'},  $rates{'EURILS'}\n"; 
