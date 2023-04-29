#!/usr/bin/perl
#
usue strict;
use warnings;

# basic form of query:
# sqlite3 exchange_rates.sqlite -csv -header 
#	"select 
#		USD.date, 1, USD.HKD, AUD.HKD 
#	from USD 
#		Join AUD on AUD.timestamp = USD.timestamp
#		order by USD.timestamp;"
