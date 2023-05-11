#!/usr/bin/env python3
"""
    Script to do stuff in Python.

    Manage the Connections and the APP
    Usage:
        With no arguments, get todays exchange rates from the api
        with any argument, get the time series data and infill.
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
              102: ('The account this API request is coming from is '
                    'inactive.'),
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
                        credentials: dict):
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
    for_real = True
    symbol_list = ','.join(symbols)
    baseurl = 'https://api.apilayer.com/exchangerates_data'
    url = (f'{baseurl}/timeseries'
           f'?access_key={credentials["api-key"]}'
           f'&start_date={start_date}&end_date={end_date}'
           f'&base={base}&symbols={symbol_list}')
    # print(url)
    headers = {'apikey': credentials['api-key']}
    if for_real:
        response = requests.get(url, headers=headers)
        status_code = response.status_code
        if status_code in error_keys:
            print(status_code, api_errors[status_code], response)
            return None

        result = json.loads(response.text)
    else:
        # Return a dummy set for testing to save on api calls
        result = {'success': True,
                  'timestamp': 1680946803,
                  'base': 'HKD',
                  'date': '2023-04-08',
                  'rates': {'HKD': 1,
                            'USD': 0.127393,
                            'AUD': 0.190936,
                            'EUR': 0.115851,
                            'GBP': 0.102393,
                            'CNY': 0.875277,
                            'THB': 4.3432
                            }
                  }
    return result


def return_sql_command_from_data(table: str, date: str, data: dict):
    """
    return the SQL command to INSERT OR IGNORE from a dict
    of keys corresponding to a date.
    """
    date_obj = datetime.strptime(date, '%Y-%m-%d')
    timestamp = datetime.strftime(date_obj, '%Y%m%d')
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
    timestamp = datetime.strftime(end_date, '%Y%m%d')
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
                    sql_cmd, data = return_sql_command_from_data(currency,
                                                                 this_date,
                                                                 rates[date])
                    print(sql_cmd, data)
                    result = db.execute(sql_cmd, data)
                    print(result)

            db.execute('COMMIT')


def get_latest_rates(base: str,  symbols: list, credentials: dict):
    """
    Use the APILAYER API to get the requested data
    Documentation from here:
        https://exchangeratesapi.io/documentation/

        More reliable documentation here.
        https://apilayer.com/marketplace/exchangerates_data-api
    """
    for_real = True
    symbol_list = ','.join(symbols)
    baseurl = 'https://api.apilayer.com/exchangerates_data'
    url = (f'{baseurl}/latest'
           '?access_key={credentials["api-key"]}'
           f'&base={base}&symbols={symbol_list}')
    headers = {'apikey': credentials['api-key']}
    if for_real:
        response = requests.get(url, headers=headers)
        status_code = response.status_code
        if status_code in error_keys:
            print(status_code, api_errors[status_code], response)
            return None

        result = json.loads(response.text)
    else:
        # Return a dummy set for testing to save on api calls
        result = {'success': True,
                  'timestamp': 1680946803,
                  'base': 'HKD',
                  'date': '2023-04-08',
                  'rates': {'HKD': 1,
                            'USD': 0.127393,
                            'AUD': 0.190936,
                            'EUR': 0.115851,
                            'GBP': 0.102393,
                            'CNY': 0.875277,
                            'THB': 4.3432
                            }
                  }
    return result


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
                timestamp = datetime.strftime(query_ts, '%Y-%m-%d')

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
        end_date = datetime.strftime('%Y-%m-%d', datetime.now())
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
    db_connection = sqlite3.connect(f'{WORKDIR}/exchange_rates.sqlite')
    db = db_connection.cursor()
    main(sys.argv)

    # Close the connection
    db.close()
