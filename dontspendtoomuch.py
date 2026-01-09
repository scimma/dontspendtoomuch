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
    report += fetch_reserved_instances()
    report += fetch_reserved_utilization()
    print(report)

    print("retrieving slack secrets")
    secrets_client = boto3.client("secretsmanager")
    secrets_response = secrets_client.get_secret_value(
        SecretId=os.getenv("SLACK_SECRETS_ARN"))
    secrets = json.loads(secrets_response['SecretString'])
    for channel, endpoint in secrets.items():
        print(f"publishing to {channel}")
        send_to_slack(endpoint, report)


def main():
    args = parse_arguments()
    if args.email is not None:
        raise NotImplementedError("email reports are not yet implemented")

    if args.n_days:
        start = aws_date_string(
            datetime.date.today() - datetime.timedelta(days=args.n_days))
        end = aws_date_string(datetime.date.today())
    else:
        start = args.start
        end = args.end

    data = fetch(start, end)
    report = format_terminal_output(data)
    report += fetch_reserved_instances()
    report += fetch_reserved_utilization()
    if args.slack is not None:
        for endpoint in args.slack:
            send_to_slack(endpoint, report)
    print(report)


def parse_arguments(arguments=None):
    """Parse arguments from the command line, validate them, and return them."""
    parser = argparse.ArgumentParser(
        "dontspendtoomuch", description="Report on AWS usage")
    parser.add_argument("--email", action="append",
                        help="Email address to send a report to. May be specified multiple times.")
    parser.add_argument("--slack", action="append",
                        help="Slack Webhook URL to report to. May be specified multiple times.")
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
        parser.error(
            "If --n-days is provided, then --start and --end must be left blank.")

    if args.end and not args.start:
        parser.error(
            "If --end is provided, then --start must be provided too.")

    if args.start and not args.end:
        parser.error(
            "If --start is provided, then --end must be provided too.")

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
    client = boto3.client("ce")
    return client.get_cost_and_usage(
        TimePeriod={
            "Start": start,
            "End": end,
        },
        Granularity="DAILY",
        Metrics=["UNBLENDED_COST"],
    )


def fetch_reserved_instances():
    """ Fetch reserved instance information so we see when things expire"""
    # Initialize the EC2 client
    ec2 = boto3.client('ec2')

    # Fetch all reserved instances
    response = ec2.describe_reserved_instances()
    reserved_instances = response['ReservedInstances']

    items = []
    for ri in reserved_instances:
        if ri["State"] != "active":
            continue
        instance_type = ri['InstanceType']
        # State the availability zone when reservations are
        # Specific to an availabliles zone...
        zone = ri.get('AvailabilityZone', 'us-west-2')

        date = ri['End']
        expires = f"{date.year}-{date.month}-{date.day}"
        count = ri['InstanceCount']
        offering = ri['OfferingClass']
        li = [expires, instance_type, zone, count,  offering]
        items.append(li)

    items.sort()
    all = tabulate.tabulate(
        items, headers=["expires", "type", "zone", "count", "offering"])
    all = "\n\n      Reserved Instance Report for us-west-2\n\n" + all
    return all


def fetch_reserved_utilization():
    ce = boto3.client('ce')
    start = aws_date_string(datetime.date.today() - datetime.timedelta(days=30))
    end = aws_date_string(datetime.date.today())

    resp = ce.get_reservation_utilization(
        TimePeriod={
            "Start": start,
            "End": end
        }
    )
    total = resp["Total"]
    util = float(total["UtilizationPercentage"])
    od_cost = float(total["OnDemandCostOfRIHoursUsed"])
    savings = float(total["RealizedSavings"])
    report = f"""

    ****  30 day reserved utilization report
    Percentage of all reservations actually utilized: {util:.2f}
    On Demand Cost for these items: ${od_cost:.2f}
    Realized Savings: ${savings:.2f}

    """
    return report


def send_to_slack(webhook_url, report):
    payload = {
        "text": "test to improve formatting",
        "blocks": [
            {
                "type": "section",
                "text": {
                    "type": "plain_text",
                    "text": report
                }
            }
        ]
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
