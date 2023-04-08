#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Data::Dumper;

# script to get exchange rates
# modified for Jakarta project 2016/03/16
# modified to use a database 2019/03/17
# This seems to have stopped working - website changed - on 20230406
#
my $db = DBI->connect("dbi:SQLite:dbname=exchange_rates.sqlite","","") or die DBI::errstr;

my @currencies=qw(HKD USD IDR AUD PHP SGD EUR GBP CNY THB TWD);
my $firstrun = 0;
my $backfill = 0;
my $verbose = 1;
my $baseurl = "https://www.exchange-rates.org/Rate";

my %timestamps;

print("Use date format YYYYMMDD to specify a date for checking\n");
# add any dates on the command line - use the form yyyymmdd
while (my $date = shift @ARGV) {
	$timestamps{$date}++

}

# Add today's date
if ( (keys %timestamps) == 0 ) {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time);
	$mon++;
	$year += 1900;
	my $timestamp = sprintf("%04d", $year) . sprintf("%02d", $mon) . sprintf("%02d", $mday);
	$timestamps{$timestamp}++;
}

# For new running, make the tables and
if ( $firstrun == 1 ) {
	my $result = drop_all_tables($db, "");
	$result = make_tables($db);
	print "Reading from File...\n" if $verbose;
	$result = read_from_file($db, "project_rates.csv");
}

if ( $backfill == 1) {
	# get the rates for every date in the database
	print "Getting Dates...\n" if $verbose;
	my %timestamps;
	foreach my $cur1 (@currencies) {
		my @timestamps = array_from_query($db, "Select timestamp from [$cur1] order by timestamp;", $verbose);
		for my $timestamp (@timestamps) {
			$timestamps{$timestamp}++;
		}
	}
}

# get the currencies for our timestamps
my $transactions = 0;
my @timestamps = keys %timestamps;
for my $timestamp (@timestamps) {
	my $mdydate = mdydate_from_timestamp($timestamp); # The date we want is not always available
	print "getting rates for $timestamp / $mdydate\n" if $verbose;
	my ($trans_mdydate, $rates_ref) = get_currency_rates($mdydate, @currencies);
	my %rates = %$rates_ref;
	print Dumper(%rates);

	# Get the timestamp for the transaction from an MDY date
	my $trans_date = fix_date($trans_mdydate);
	my $trans_timestamp = timestamp_from_date($trans_date);

	dbdo($db, "BEGIN", $verbose);
	$transactions += add_rates_to_db($trans_timestamp, \@currencies, \%rates);
	dbdo($db, "COMMIT", $verbose);

	# add to the file
	my $date = date_from_timestamp($timestamp);
	open (my $fh, ">>", "project_rates.csv");
	print $fh "$date, $rates{'USDHKD'},  $rates{'HKDIDR'},  $rates{'USDIDR'}, $rates{'AUDIDR'}, $rates{'AUDHKD'}, $rates{'USDPHP'}, $rates{'USDSGD'}\n";
	close $fh;
}

print "$transactions items added to database.\n" if $verbose;

$db->disconnect;

## Subroutines
sub read_from_file {
	my $db = shift;
	my $file = shift;

	open( my $fh, "<", $file) or die "Caan't open $file. $!";
	my @from = qw/USD HKD USD AUD USD USD USD/;
	my @to   = qw/HKD IDR IDR IDR HKD PHP SGD/;
	dbdo($db, "BEGIN", $verbose);
	while (my $line = <$fh>) {
		chomp $line;
		my ($date, @rates) = split ", ", $line;
		my $idx = 0;

		my $timestamp = timestamp_from_date($date);
		foreach my $rate (@rates) {
			my $result = db_upsert($db,
								   "Select Date, $to[$idx] from [$from[$idx]] where Date = \"$date\";",
								   "Insert or Replace into [$from[$idx]] (Timestamp, Date, $to[$idx]) Values (\"$timestamp\", \"$date\", $rate) ",
								   "Update [$from[$idx]] SET $to[$idx] = $rate where Date = \"$date\";",
								   $verbose);
			$idx++;
		}
	}
	dbdo($db, "COMMIT", $verbose);

	close $fh;
}

sub add_rates_to_db {
	# add the rates to the database tables and return the number of transactions
	my $timestamp = shift;
	my $currency_ref = shift;
	my $rates_ref = shift;

	my @currencies = @$currency_ref;
	my %rates = %$rates_ref;
	my $date = date_from_timestamp($timestamp);

	my $transactions = 0;
	foreach my $cur1 (@currencies) {
		foreach my $cur2 (@currencies) {
			# check if we've seen this one before (and is it different?)
			my $rate = $rates{$cur1.$cur2};
			my $result = db_upsert($db,
								   "Select * from [$cur1] where timestamp = \'$timestamp\';",
								   "Insert or Replace into [$cur1] (Timestamp, Date, $cur2) Values (\"$timestamp\", \"$date\", $rate);",
								   "Update [$cur1] SET $cur2 = $rate where timestamp = \'$timestamp\';",
								   $verbose);
			print "\t$timestamp: $cur1 -> $cur2 = $rate\n" if $verbose;;
			$transactions++;
		}
	}

	return $transactions;
}

sub get_currency_rates {
	# given
	my $date = shift;
	my @currencies = @_;

	my %rates;
	my $trans_mdydate;

	foreach my $cur1 (@currencies) {
		print "Looking for $baseurl/$cur1/.../$date...\n" if $verbose;
		foreach my $cur2 (@currencies) {
			if ($cur1 eq $cur2) {
				$rates{$cur1.$cur2}=1.0;
			} else {
				my $curl_options = "--compressed --silent";
				my $curl_cmd = "$curl_options $baseurl/$cur1/$cur2/$date";
				print "$curl_cmd\n";
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
						print "\tRate at $date for $cur1 to $cur2 is $rate.\n" if $verbose;
					}
					#</tr><tr>
					#	<td class="text-nowrap"><i class="flag"><span class="id"></span></i>1,000,000 IDR</td>
					#	<td class="text-nowrap text-narrow-screen-wrap"><i class="flag"><span class="us"></span></i>USD</td>
					#	<td class="text-nowrap text-narrow-screen-wrap">76.7843 USD</td>
					#	<td class="text-narrow-screen-hidden text-wrap">1,000,000 Indonesian Rupiahs in US Dollars is 76.7843 for 3/11/2016</td>
					#</tr>
					if ( ($line =~ />(1,000,000) .* in .* is ([0-9.,]+) for ([0-9\/]+)<\/td>/) or
						 ($line =~ />(1,000,000) .* = ([0-9.,]+) .* on ([0-9\/]+)<\/td>/)) {
						#print "$line\n";
						my $cur1_amount = $1;
						my $cur2_amount = $2;
						$trans_mdydate = $3;
						$cur1_amount =~ s/,//g;
						$cur2_amount =~ s/,//g;
						$rates{$cur1.$cur2} = ($cur2_amount / $cur1_amount);
						#print "$line\n";
						print "\tRate for $cur1 to $cur2 is $cur2_amount for $cur1_amount on $trans_mdydate.\n";
					}

				}
				close $infh
			}
		}
	}
	return ($trans_mdydate, \%rates);
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

sub make_tables {
	my $db = shift;
	my %countries = ("HKD"=>"Hong Kong", "USD"=>"United States",
					  "IDR"=>"Indonesia", "AUD"=>"Australia",
					  "PHP"=>"Philippines","SGD"=>"Singapore",
					  "EUR"=>"Europe", "GBP"=>"United Kingdom",
					  "CNY"=>"China", "TWD"=>"Taiwan",
					  "THB"=>"Thailand");
	my %tables= (
		"Currencies" => "abbrev TEXT Primary Key, Country Text"
		);
	my @currencies = keys %countries;
	for my $curr1 (@currencies) {
		my $definition = "Timestamp Text Primary Key, Date TEXT";
		for my $curr2 ( @currencies ) {
			$definition .= ", $curr2 Real";
		}
		$tables{$curr1} = $definition;
	}

    foreach my $tablename (%tables) {
        if (exists $tables{$tablename} ) {
            my $command = "Create Table if not exists [$tablename] ($tables{$tablename})";
            my $result = dbdo($db, $command, $verbose);
        }
    }
}

sub drop_all_tables {
    # get a list of table names from $db and drop them all
    my $db = shift;
    my $prefix = shift;
    my @tables;
    my $query = querydb($db, "select name from sqlite_master where type='table' and name like '$prefix%' order by name", 1);
    # we need to extract the list of tables first - sqlite doesn't like
    # multiple queries at the same time.
    while (my @row = $query->fetchrow_array) {
        push @tables, $row[0];
    }
    dbdo ($db, "BEGIN", 1);
    foreach my $table (@tables) {
        dbdo ($db, "DROP TABLE if Exists [$table]", 1);
    }
    dbdo ($db, "COMMIT", 1);
    return 1;
}
sub querydb {
    # prepare and execute a query
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    print "\tQUERYDB: $db: $command\n" if $verbose;
    my $query = $db->prepare($command) or die $db->errstr;
    $query->execute or die $query->errstr;
    return $query;
}

sub dbdo {
    my $db = shift;
    my $command = shift;
    my $verbose = shift;

    if (length($command) > 1000000) {
        die "$command too long!";
    }
    #print "\t$db: ".length($command)." $command\n" if $verbose;
    my $result = $db->do($command) or die $db->errstr . "\nwith: $command\n";
    return $result;
}
sub array_from_query {
    # return an array from a query which results in one item per line
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my @results;
    my $query = querydb($db, $command, $verbose);
    while (my @row = $query->fetchrow_array) {
        push @results, $row[0];
    }
    return (@results);
}
sub hash_from_query {
    # return an array from a query which results in two items per line
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my %results;
    my $query = querydb($db, $command, $verbose);
    while (my @row = $query->fetchrow_array) {
        $results{$row[0]} = $row[1];
    }
    #print Dumper(%results);
    return (\%results);
}
sub row_from_query {
    # return a single row response from a query (actually, the first row)
    my $db = shift;
    my $command = shift;
    my $verbose = shift;
    my $query = querydb($db, $command, $verbose);
    my @results = $query->fetchrow_array;
    return (@results);
}

sub db_upsert {
	#  Check if a transaction would cause a conflict and do an update instead
	my $db = shift;
	my $check = shift;
	my $cmd1 = shift;
	my $cmd2 = shift;
	my $verbose = shift;

	my @row = row_from_query($db, $check, $verbose);
	my $results;
	#print Dumper(@row) if $verbose;
	if ( !(@row) ) {
		# if row not defined we do the insert
		print "\t$cmd1\n" if $verbose;
		$results = dbdo($db, $cmd1, $verbose);
	} else {
		# otherwise do the update
		print "\t$cmd2\n" if $verbose;
		$results = dbdo($db, $cmd2, $verbose);
	}

	return $results;
}

sub timestamp_from_date {
	my $date = shift;
	my ($day, $month, $year) = split "/", $date;
	my $timestamp = sprintf("%04d", $year) . sprintf("%02d", $month) . sprintf("%02d", $day);
	return $timestamp;
}
sub date_from_timestamp {
	# return dd/mm/yyyy from yyyymmdd
	my $timestamp = shift;
	my $year  = substr($timestamp, 0, 4);
	my $month = substr($timestamp, 4, 2);
	my $day   = substr($timestamp, 6, 2);
	my $date = sprintf("%02d", $day) . "/" . sprintf("%02d", $month) . "/" . sprintf("%04d", $year);
	return $date;
}
sub mdydate_from_timestamp {
	# return mm-dd-yyyy from yyyymmdd
	my $timestamp = shift;
	my $year  = substr($timestamp, 0, 4);
	my $month = substr($timestamp, 4, 2);
	my $day   = substr($timestamp, 6, 2);
	my $date = sprintf("%02d", $month) . "-" . sprintf("%02d", $day) . "-" . sprintf("%04d", $year);
	return $date;
}
