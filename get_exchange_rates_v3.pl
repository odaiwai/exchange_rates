#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# script to get exchange rates 
# modified for Jakarta project 2016/03/16
#
my @currencies=qw(HKD USD IDR AUD PHP SGD);
my $usedate=shift @ARGV;
my $firstrun = 0;
my $date;
if ( !$usedate ) {
	$date = `date +%m-%d-%Y`;
	chomp $date;
} else {
	$date = $usedate;
}

my $trans_date; #transaction date
my $baseurl = "http://www.exchange-rates.org/Rate";
my %rates = get_currency_rates($date, @currencies);
#print Dumper(%rates);
foreach my $cur1 (@currencies) {
	foreach my $cur2 (@currencies) {
		print "$cur1 -> $cur2 = $rates{$cur1.$cur2}\n";
	}
} 
open (my $fh, ">>", "project_rates.csv");
print $fh fix_date($trans_date). ", $rates{'USDHKD'},  $rates{'HKDIDR'},  $rates{'USDIDR'}, $rates{'AUDIDR'}, $rates{'AUDHKD'}, $rates{'USDPHP'}, $rates{'USDSGD'}\n"; 
close $fh;

## Subroutines
sub get_currency_rates {
	# given 
	my $date = shift;
	my @currencies = @_;
	foreach my $cur1 (@currencies) {
		foreach my $cur2 (@currencies) {
			if ($cur1 eq $cur2) {
				$rates{$cur1.$cur2}=1.0;
			} else {
				print "Looking for $baseurl/$cur1/$cur2/$date...\n";
				my $curl_options = "--compressed --silent";
				my $curl_cmd = "$curl_options $baseurl/$cur1/$cur2/$date";
				#my @file = `curl $curl_cmd`;
				open (my $infh, "-|", "curl $curl_cmd");
				#foreach my $line (@file) {
				while (my $line = <$infh>) {
					chomp $line;
					#print "$line\n";
					# <span id="ctl00_M_grid_ctl05_lblResult">96,473.57 EUR</span>
					if ( $line =~ /\<span id\=\"ctl00_M_grid_ctl05_lblResult\"\>([0-9,.]+) [A-Z]+\<\/span\>/){
						my $rate = ($1);
						$rate =~ s/,//g;
						$rates{$cur1.$cur2} = $rate / 1000000;
						#print "$line\n";
						print "Rate for $cur1 to $cur2 is $rate.\n";
					}
					#</tr><tr>
					#	<td class="text-nowrap"><i class="flag"><span class="id"></span></i>1,000,000 IDR</td>
					#	<td class="text-nowrap text-narrow-screen-wrap"><i class="flag"><span class="us"></span></i>USD</td>
					#	<td class="text-nowrap text-narrow-screen-wrap">76.7843 USD</td>
					#	<td class="text-narrow-screen-hidden text-wrap">1,000,000 Indonesian Rupiahs in US Dollars is 76.7843 for 3/11/2016</td>
					#</tr>
					if ( ($line =~ /<\/i>(1,000,000) .* in .* is ([0-9.,]+) for ([0-9\/]+)<\/td>/) or
						 ($line =~ /<\/i>(1,000,000) .* = ([0-9.,]+) .* on ([0-9\/]+)<\/td>/)) {
						#print "$line\n";
						my $cur1_amount = $1;
						my $cur2_amount = $2;
						$trans_date = $3;
						$cur1_amount =~ s/,//g;
						$cur2_amount =~ s/,//g;
						$rates{$cur1.$cur2} = ($cur2_amount / $cur1_amount);
						#print "$line\n";
						print "Rate for $cur1 to $cur2 is $cur2_amount for $cur1_amount on $trans_date.\n";
					}
				
				}
				close $infh
			}
		}
	}
	return %rates;
}

sub fix_date {
	# given a date in m/d/yyyy, fix it to be dd/mm/yyyy
	my $wrong_date = shift;
	my ($month, $day, $year) = split "/", $wrong_date;
	return "$day/$month/$year";
}

sub get_all_dates {
	# get all the data from 11 March 2016
	my $start_date = "11/03/2016"
}
