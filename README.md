# README

Utility to retrieve the Exchanges Rates for a number of currencies every week/day

Was in Perl, relying on WebScraping, but that stopped working in 2023, so re-written
in Python using a free API with limited accesses per month;

## Credentials
to sign-up for the API key, go here: https://apilayer.com/marketplace/exchangerates_data-api 
and complete the sign-up process. For such a low-volume task as this one, the 
free tier is fine.
Credentials are stored in a `credentials.json` file, which is not in the repo, for 
obvious reasons. This file is of the form:

    {
        "api-key": "[REDACTED]"
    }
This credential will be given when you register for the API service.

## Completed Tasks
 - Perl scripts has stopped working on 2023/04/08 due to external site changes
 - Replaced with Python utility and API access from here: 
 - https://exchangeratesapi.io/documentation/ instead

## TODO:
Task to be undertaken in the future
1. infill the earlier dates with: - Done

    `for year in $(seq 2006 2015); do ./get_exchange_rates.py $year-12-31 365; done`
2. Tidy up the API response. - Done
3. Remove the credentials from the Development Branch - Done
4. Normalize the timestamp - it should be '%Y%m%d_%H%M%S' everywhere - Done
5. Deal with some of the older entries having identical timestamps and different data. This is due to multiple retrievals on the same day, but the older data only recorded the timestamp to the nearest day. - Pending
