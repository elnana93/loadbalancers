
import json
import os
import time
from datetime import datetime, timedelta, timezone

import boto3

AWS_REGION = os.getenv("AWS_REGION", os.getenv("AWS_DEFAULT_REGION", "us-west-2"))
WAF_LOG_GROUP = os.getenv("WAF_LOG_GROUP", "").strip()
QUERY_WINDOW_MINUTES = int(os.getenv("QUERY_WINDOW_MINUTES", "15"))
QUERY_TIMEOUT_SECONDS = int(os.getenv("QUERY_TIMEOUT_SECONDS", "25"))
QUERY_POLL_INTERVAL_SECONDS = int(os.getenv("QUERY_POLL_INTERVAL_SECONDS", "2"))

logs_client = boto3.client("logs", region_name=AWS_REGION)


def log(message, **kwargs):
    payload = {"message": message}
    if kwargs:
        payload.update(kwargs)
    print(json.dumps(payload, default=str))


def safe_json_loads(value):
    try:
        return json.loads(value)
    except Exception:
        return value


def parse_timestamp(value):
    if not value:
        return datetime.now(timezone.utc)

    candidates = [
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S",
    ]

    cleaned = value.replace("Z", "+0000")
    if cleaned.endswith("+00:00"):
        cleaned = cleaned.replace("+00:00", "+0000")

    for fmt in candidates:
        try:
            dt = datetime.strptime(cleaned, fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc)
        except ValueError:
            continue

    return datetime.now(timezone.utc)


def normalize_results(results):
    rows = []
    for row in results:
        item = {}
        for field in row:
            item[field.get("field", "")] = field.get("value", "")
        rows.append(item)
    return rows


def extract_alarm_context(record):
    sns = record.get("Sns", {})
    raw_message = sns.get("Message", "")
    parsed = safe_json_loads(raw_message)

    if isinstance(parsed, dict):
        return {
            "alarm_name": parsed.get("AlarmName", "UnknownAlarm"),
            "new_state_value": parsed.get("NewStateValue", "UNKNOWN"),
            "new_state_reason": parsed.get("NewStateReason", ""),
            "state_change_time": parsed.get("StateChangeTime"),
            "raw_alarm": parsed,
            "sns_subject": sns.get("Subject", ""),
            "sns_topic_arn": sns.get("TopicArn", ""),
            "sns_message_id": sns.get("MessageId", ""),
        }

    return {
        "alarm_name": sns.get("Subject", "UnknownAlarm"),
        "new_state_value": "UNKNOWN",
        "new_state_reason": "SNS message was not CloudWatch alarm JSON.",
        "state_change_time": None,
        "raw_alarm": raw_message,
        "sns_subject": sns.get("Subject", ""),
        "sns_topic_arn": sns.get("TopicArn", ""),
        "sns_message_id": sns.get("MessageId", ""),
    }


def build_query_window(alarm_context):
    state_dt = parse_timestamp(alarm_context.get("state_change_time"))
    start_dt = state_dt - timedelta(minutes=QUERY_WINDOW_MINUTES)
    end_dt = state_dt + timedelta(minutes=1)

    now_dt = datetime.now(timezone.utc)
    if end_dt > now_dt:
        end_dt = now_dt

    return int(start_dt.timestamp()), int(end_dt.timestamp())


def run_waf_query(start_time, end_time):
    if not WAF_LOG_GROUP:
        raise ValueError("Missing WAF_LOG_GROUP environment variable")

    query_string = """
fields @timestamp, action, httpRequest.clientIp, httpRequest.country, httpRequest.uri, httpRequest.httpMethod, terminatingRuleId
| sort @timestamp desc
| limit 20
""".strip()

    start_resp = logs_client.start_query(
        logGroupName=WAF_LOG_GROUP,
        startTime=start_time,
        endTime=end_time,
        queryString=query_string,
    )

    query_id = start_resp["queryId"]
    deadline = time.time() + QUERY_TIMEOUT_SECONDS

    while time.time() < deadline:
        result_resp = logs_client.get_query_results(queryId=query_id)
        status = result_resp["status"]

        if status == "Complete":
            return {
                "query_id": query_id,
                "status": status,
                "rows": normalize_results(result_resp.get("results", [])),
                "statistics": result_resp.get("statistics", {}),
            }

        if status in ("Cancelled", "Failed", "Timeout", "Unknown"):
            return {
                "query_id": query_id,
                "status": status,
                "rows": [],
                "statistics": result_resp.get("statistics", {}),
            }

        time.sleep(QUERY_POLL_INTERVAL_SECONDS)

    return {
        "query_id": query_id,
        "status": "TIMEOUT_WAITING_FOR_COMPLETE",
        "rows": [],
        "statistics": {},
    }


def lambda_handler(event, context):
    log("Incident reporter invoked", event=event)

    if not WAF_LOG_GROUP:
        raise ValueError("WAF_LOG_GROUP environment variable is required")

    records = event.get("Records", [])
    if not records:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "No Records found in event"})
        }

    processed = []

    for record in records:
        if record.get("EventSource") != "aws:sns":
            log("Skipping non-SNS record", record=record)
            continue

        alarm_context = extract_alarm_context(record)
        start_time, end_time = build_query_window(alarm_context)

        log(
            "Running WAF query",
            alarm_name=alarm_context.get("alarm_name"),
            state=alarm_context.get("new_state_value"),
            start_time=start_time,
            end_time=end_time,
            log_group=WAF_LOG_GROUP,
        )

        waf_results = run_waf_query(start_time, end_time)

        log(
            "WAF query complete",
            alarm_name=alarm_context.get("alarm_name"),
            status=waf_results.get("status"),
            rows_found=len(waf_results.get("rows", [])),
            sample_rows=waf_results.get("rows", [])[:5],
        )

        processed.append({
            "alarm_name": alarm_context.get("alarm_name"),
            "state": alarm_context.get("new_state_value"),
            "query_status": waf_results.get("status"),
            "rows_found": len(waf_results.get("rows", [])),
        })

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Incident reporter completed",
                "processed": processed,
            },
            indent=2,
        ),
    }