#!/bin/bash

sqlite3 exchange_rates.sqlite -header -csv <query.sql
