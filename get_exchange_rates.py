#!/usr/bin/env python3
"""
    Use the API to get exchange rate data and put it in a database.

    Manage the Connections and the APP
    Usage:
        With no arguments, get todays exchange rates from the api
        With one argument, treat the argument as a number of days to get
        results for
        with two arguments, treat the first argument as a dat, and the second
        as a number of days and get a time series.
"""

# import os
import sys
from datetime import datetime
from datetime import timedelta
import json
import pathlib
import sqlite3
import requests

api_errors = {101: ('No API Key was specified or an invalid API Key was '
                    'specified.'),
              102: ('The account this API request is coming from is '
                    'inactive.'),
              103: ('The requested API endpoint does not exist.'),
              104: ('The maximum allowed API amount of monthly API requests '
                    'has been reached.'),
              105: ('The current subscription plan does not support this API '
                    'endpoint.'),
              106: ('The current request did not return any results.'),
              201: ('An invadid base currency has been entered.'),
              202: ('One or more invalid symbols have been specified.'),
              301: ('No date has been specified. [historical]'),
              302: ('An invalid date has been specified. [historical, '
                    'convert]'),
              403: ('No or an invalid amount has been specified. [convert]'),
              404: ('The requested resource does not exist.'),
              429: ('API request limit exceeded. See section Rate Limiting '
                    'for more info.'),
              501: ('No or an invalid timeframe has been specified. '
                    '[timeseries]'),
              502: ('No or an invalid "start_date" has been specified. '
                    '[timeseries, fluctuation]'),
              503: ('No or an invalid "end_date" has been specified. '
                    '[timeseries, fluctuation]'),
              504: ('An invalid timeframe has been specified. [timeseries, '
                    'fluctuation]'),
              505: ('The specified timeframe is too long, exceeding 365 days.'
                    ' [timeseries, fluctuation]')
              }
error_keys = list(api_errors)
WORKDIR = pathlib.Path(__file__).parent.resolve()
print(f'{WORKDIR}')
TS_STRFT = '%Y%m%d_%H%M%S'
DT_STRFT = '%Y-%m-%d %H:%M:%S'

def get_credentials():
    """
    Get the API key from the credentials file.
    """

    credentials = {}
    with open(f'{WORKDIR}/credentials.json', 'r', encoding='utf-8') as creds:
        credentials = json.loads(creds.read())

    # print(credentials.keys())
    return credentials


def get_time_series_api(base: str,
                        symbols: list,
                        date: str,
                        extent: int,
                        credentials: dict) -> dict | None:
    """
    Use the APILAYER API to get the requested data
    Documentation from here:
        https://exchangeratesapi.io/documentation/

        More reliable documentation here.
        https://apilayer.com/marketplace/exchangerates_data-api?e=Sign+Up&l=Success
    """
    # print(date)
    start_date = datetime.strftime(date - timedelta(extent), '%Y-%m-%d')
    end_date = datetime.strftime(date, '%Y-%m-%d')
    symbol_list = ','.join(symbols)
    baseurl = 'https://api.apilayer.com/exchangerates_data'
    url = (f'{baseurl}/timeseries'
           # f'?access_key={credentials["api-key"]}'
           f'&start_date={start_date}&end_date={end_date}'
           f'&base={base}&symbols={symbol_list}')
    # print(url)
    data = get_data_from_api(url, credentials, True)
    return data


def get_data_from_api(url: str,
                      credentials: dict,
                      for_real: bool) -> dict | None:
    """
    Make a call to the API with a url and return the data from it.
    """
    headers = {'apikey': credentials['api-key']}
    if for_real:
        # print(url, headers)
        response = requests.get(url, headers, timeout=30)
        print(f'Code: {response.status_code}')
        if response.status_code in error_keys:
            api_response = json.loads(response.content.decode())
            print(f'{api_errors[response.status_code]}\n',
                  f'{api_response["message"]}')
            return None
        # No status code in the error list
        # Must be a successful
        return json.loads(response.text)

    # Return a dummy set for testing to save on api calls
    return {'success': True,
            'timestamp': 1680946803,
            'base': 'HKD',
            'date': '2023-04-08',
            'rates': {'HKD': 1,
                      'USD': 0.127393, 'AUD': 0.190936, 'EUR': 0.115851,
                      'GBP': 0.102393, 'CNY': 0.875277, 'THB': 4.3432
                      }
            }


def sql_command_from_data(table: str, date: str, data: dict):
    """
    return the SQL command to INSERT OR IGNORE from a dict
    of keys corresponding to a date.
    """
    date_obj = datetime.strptime(data['date'], '%Y-%m-%d')
    ts_obj = datetime.fromtimestamp(data['timestamp'])
    timestamp = datetime.strftime(ts_obj, TS_STRFT )
    keys_list = data.keys()
    keys = ', '.join(keys_list)
    pars = ', '.join(['?'] * (2+len(keys_list)))
    vals_list = data.values()
    sql_cmd = (f'INSERT OR IGNORE INTO [{table}] '
               f'(Timestamp, Date, {keys}) '
               f'Values ({pars})')
    # print(sql_cmd, (timestamp, date,) + tuple(vals_list))
    return sql_cmd, (timestamp, date,) + tuple(vals_list)


def get_time_series(date: str, extent: int) -> None:
    """
    Get the time series data from the API, save a copy to disk
    and insert or ignore into the database
    """
    currencies = 'HKD USD IDR AUD PHP SGD EUR GBP CNY THB TWD'.split(' ')
    ts_dir = f'{WORKDIR}/time_series'
    end_date = datetime.strptime(date, '%Y-%m-%d')
    timestamp = datetime.strftime(end_date, TS_STRFT)
    if extent == 0:
        extent = 365
    print(f'Time Series ({date} {extent}): getting credentials...')
    credentials = get_credentials()
    for currency in currencies:
        print(currency, currencies)
        result = get_time_series_api(currency,
                                     currencies,
                                     end_date,
                                     extent,
                                     credentials)
        if result is not None:
            db.execute('BEGIN')
            with open(f'{ts_dir}/time_series_{currency}_{timestamp}.json',
                      'w',
                      encoding='utf-8') as outfh:
                print(json.dumps(result), file=outfh)
                rates = result['rates']
                for this_date in rates:
                    sql_cmd, data = sql_command_from_data(currency,
                                                          this_date,
                                                          rates[date])
                    print(sql_cmd, data)
                    result = db.execute(sql_cmd, data)
                    print(result)

            db.execute('COMMIT')


def get_latest_rates(base: str,
                     symbols: list,
                     credentials: dict) -> dict | None:
    """
    Use the APILAYER API to get the requested data
    Documentation from here:
        https://exchangeratesapi.io/documentation/

        More reliable documentation here.
        https://apilayer.com/marketplace/exchangerates_data-api
    """
    symbol_list = ','.join(symbols)
    baseurl = 'https://api.apilayer.com/exchangerates_data'
    url = (f'{baseurl}/latest'
           f'&base={base}&symbols={symbol_list}')
    print(url)
    data = get_data_from_api(url, credentials, True)
    return data


def create_tables():
    """
    create the tables and indices in case of restarting from scratch
    """
    currencies = 'HKD USD IDR AUD PHP SGD EUR GBP CNY THB TWD'.split(' ')
    curr_schema = ', '.join([f'{curr} REAL' for curr in currencies])
    for currency in currencies:
        sql_cmd = (f'CREATE TABLE [{currency}] ('
                   'TIMESTAMP TEXT UNIQUE PRIMARY KEY, '
                   f'DATE TEXT, {curr_schema})')
        db.execute("BEGIN")
        db.execute(sql_cmd)
        db.execute((f'CREATE UNIQUE INDEX {currency}_IDX '
                    f'ON {currency} (TIMESTAMP)'))
        db.execute("COMMIT")


def main(args):
    """
        Get the latest currency rates
    """
    currencies = 'HKD USD IDR AUD PHP SGD EUR GBP CNY THB TWD'.split(' ')
    # currencies = 'HKD USD AUD EUR GBP CNY THB'.split(' ')
    credentials = get_credentials()
    print(f'Credentials: {credentials}')

    if len(args) == 1:
        for currency in currencies:
            result = get_latest_rates(currency, currencies, credentials)
            if result is not None:
                date = result['date']
                query_ts = datetime.fromtimestamp(result['timestamp'])
                timestamp = datetime.strftime(query_ts, TS_STRFT)

                print(result['rates'])
                curr_list = result['rates'].keys()
                rate_list = result['rates'].values()
                print(curr_list, rate_list)
                currs = ', '.join(curr_list)
                rates = ', '.join([str(r) for r in rate_list])
                pars = ', '.join(['?'] * (2+len(curr_list)))
                print(timestamp, date, curr_list, rate_list)
                sql_cmd = (f'INSERT OR IGNORE INTO [{currency}] '
                           f'(Timestamp, Date, {currs}) '
                           f'Values ({pars})')
                print(sql_cmd, (timestamp, date, rates, ))
                db.execute("BEGIN")
                db.execute(sql_cmd, (timestamp, date,) + tuple(rate_list))
                db.execute("COMMIT")
                # dbc.('INSERT INTO HKD (Timestamp, Date, c...) Values ()
    elif len(args) == 2:
        end_date = datetime.strftime(datetime.now(), '%Y-%m-%d')
        get_time_series(end_date, int(sys.argv[1]))
    elif len(args) == 3:
        get_time_series(sys.argv[1], int(sys.argv[2]))
    else:
        print('Usage: 1 argument, extent of time series in days.')
        print(f'       e.g.: {sys.argv[0]} 30 returns the last 30 days')
        print('       2 arguments: end date and extent of time series.')
        print(f'       e.g.  {sys.argv[0]} 2012-12-31 365 ')
        print('       returns 365 days from that date.')


if __name__ == '__main__':
    with sqlite3.connect(f'{WORKDIR}/exchange_rates.sqlite') as connect:
        db = connect.cursor()
        main(sys.argv)

