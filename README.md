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
This barnch is used for deployiing as a lambda.

== inspect Makefile variables -- for using the terrafrom managed python version
# make venv            # This is custom method for this project.
== Make changes to python code. you might also want to interact with AWS cosole  editor/tester to verify your changes.
# make deploy          # Bundle and push the code to S3 (code is not yet used by lambda)
# make deploy-activate # Make the most recent deploy used by the lambda

Note that there is a teraaform module in aws-dev that sets the lambda environment up, including the python version 

Prerequisities: GNU Make and `virtualenv`. Then, lint with `make lint` and test
with `make test`.
