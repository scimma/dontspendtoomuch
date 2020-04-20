# dontspendtoomuch #

This is a little script for getting cost data from AWS and publishing it to
email and slack channels.

## Installation ##
Clone, and then `pip install .`. You now have `dontspendtoomuch.py` installed.

## Usage ##

```
usage: dontspendtoomuch.py [-h] [--email EMAIL] [--slack SLACK] [--start START] [--end END] [-n N_DAYS]

Report on AWS usage

optional arguments:
  -h, --help            show this help message and exit
  --email EMAIL         Email address to send a report to. May be specified multiple times.
  --slack SLACK         Slack channels to send a report to. May be specified multiple times.
  --start START         Oldest date to include in the report, in YYYY-MM-DD format.
  --end END             Newest date to include in the report, in YYYY-MM-DD format.
  -n N_DAYS, --n-days N_DAYS
                        Number of days of data to retrieve.
```

## Development ##

Prerequisities: GNU Make and `virtualenv`. Then, lint with `make lint` and test
with `make test`.
