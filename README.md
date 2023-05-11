# README

Utility to retrieve the Exchanges Rates for a number of currencies every week/day

Was in Perl, relying on WebScraping, but that stopped working in 2023, so re-written
in Python using a free API with limited accesses.

## Completed Tasks
 - Perl scripts has stopped working on 2023/04/08 due to external site changes
 - Can try to bodge it to fix, but might be better off going to use https://exchangeratesapi.io/documentation/ instead

## TODO:
Task to be undertaken in the future
1. infill the earlier dates with:

    for year in `seq 2006 2015`; do ./get_exchange_rates.py $year-12-31 365; done
