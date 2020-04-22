import os
import json
import datetime
import argparse
import boto3
import tabulate
import requests


def lambda_handler(event, context):
    """ Entrypoint when running from within AWS Lambda """
    start = aws_date_string(datetime.date.today() - datetime.timedelta(days=7))
    end = aws_date_string(datetime.date.today())
    data = fetch(start, end)
    report = format_terminal_output(data)
    print(report)

    print("retrieving slack secrets")
    secrets_client = boto3.client("secretsmanager")
    secrets_response = secrets_client.get_secret_value(SecretId=os.getenv("SLACK_SECRETS_ARN"))
    secrets = json.loads(secrets_response['SecretString'])
    for channel, endpoint in secrets.items():
        print(f"publishing to {channel}")
        send_to_slack(endpoint, report)


def main():
    args = parse_arguments()
    if args.email is not None:
        raise NotImplementedError("email reports are not yet implemented")

    if args.n_days:
        start = aws_date_string(datetime.date.today() - datetime.timedelta(days=args.n_days))
        end = aws_date_string(datetime.date.today())
    else:
        start = args.start
        end = args.end

    data = fetch(start, end)

    report = format_terminal_output(data)
    if args.slack is not None:
        for endpoint in args.slack:
            send_to_slack(endpoint, report)
    print(report)


def parse_arguments(arguments=None):
    """Parse arguments from the command line, validate them, and return them."""
    parser = argparse.ArgumentParser("dontspendtoomuch", description="Report on AWS usage")
    parser.add_argument("--email", action="append",
                        help="Email address to send a report to. May be specified multiple times.")
    parser.add_argument("--slack", action="append",
                        help="Slack Webhook URL to send a report to. May be specified multiple times.")

    parser.add_argument("--start",
                        help="Oldest date to include in the report, in YYYY-MM-DD format.")
    parser.add_argument("--end",
                        help="Newest date to include in the report, in YYYY-MM-DD format.")
    parser.add_argument("-n", "--n-days", type=int,
                        help="Number of days of data to retrieve.")
    if arguments is None:
        args = parser.parse_args(arguments)
    else:
        args = parser.parse_args()

    # Validation and string parsing ensues:
    if not args.n_days and not args.start and not args.end:
        parser.error("Either --n-days or --start and --end must be provided.")
    if args.n_days and (args.end or args.start):
        parser.error("If --n-days is provided, then --start and --end must be left blank.")

    if args.end and not args.start:
        parser.error("If --end is provided, then --start must be provided too.")

    if args.start and not args.end:
        parser.error("If --start is provided, then --end must be provided too.")

    if args.start and args.end:
        try:
            datetime.datetime.strptime(args.start, "%Y-%m-%d")
        except ValueError:
            parser.error("--start must be in YYYY-MM-DD format")
        try:
            datetime.datetime.strptime(args.end, "%Y-%m-%d")
        except ValueError:
            parser.error("--end must be in YYYY-MM-DD format")

    return args


def aws_date_string(date):
    """ Format a datetime.date object in AWS's date string style."""
    return date.strftime("%Y-%m-%d")


def fetch(start, end):
    """Get data from AWS on cost and usage. Start and end should be strings in the
    format YYYY-MM-DD."""
    print("initializing client")
    id = boto3.client("sts").get_caller_identity()
    print(f"identity: {id}")
    client = boto3.client("ce")
    return client.get_cost_and_usage(
        TimePeriod={
            "Start": start,
            "End": end,
        },
        Granularity="DAILY",
        Metrics=["UNBLENDED_COST"],
    )


def send_to_slack(webhook_url, report):
    payload = {
        "text": report,
    }
    requests.post(webhook_url, json=payload)


def format_terminal_output(report):
    """Format the response from a CostExplorer GetCostAndUsage report into a
    table."""
    data = [[day["TimePeriod"]["Start"], day["Total"]["UnblendedCost"]["Amount"]]
            for day in report["ResultsByTime"]]
    return tabulate.tabulate(data, headers=["day", "spend (USD)"])


if __name__ == "__main__":
    main()
