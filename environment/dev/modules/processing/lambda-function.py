import boto3
import csv
import os
import json
from urllib.parse import unquote_plus

s3       = boto3.client('s3')
sns      = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')

def send_sns_notification(topic_arn, subject, message):
    """Helper to ensure SNS failures don't crash the primary Lambda logic."""
    if not topic_arn or topic_arn == 'MISSING_TOPIC_ARN':
        print("SNS Alert skipped: Topic ARN is missing or not configured.")
        return
    try:
        sns.publish(TopicArn=topic_arn, Subject=subject, Message=message)
    except Exception as e:
        print(f"Failed to send SNS alert: {str(e)}")

def lambda_handler(event, context):
    # 1. Parse Event and Environment
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    file_key    = unquote_plus(event['Records'][0]['s3']['object']['key'])
    table_name  = os.environ.get('DYNAMODB_TABLE', 'MISSING_TABLE_NAME')
    topic_arn   = os.environ.get('SNS_TOPIC_ARN', 'MISSING_TOPIC_ARN')

    print(f"Processing: {file_key} | Table: {table_name}")

    try:
        # 2. Retrieve and Decode File
        response = s3.get_object(Bucket=bucket_name, Key=file_key)
        # 'utf-8-sig' handles the 'Byte Order Mark' (BOM) hidden character from Excel
        content  = response['Body'].read().decode('utf-8-sig')
        lines    = content.splitlines()

        reader = csv.DictReader(lines)
        table  = dynamodb.Table(table_name)

        count = 0
        for row in reader:
            # 3. Aggressive Key Cleaning
            # Strips whitespace AND converts to lowercase (e.g., 'Order_ID ' -> 'order_id')
            clean_row = {k.strip().lower(): v.strip() for k, v in row.items() if k}
            
            # Debug: Log the actual keys found in the first row
            if count == 0:
                print(f"Detected CSV Keys: {list(clean_row.keys())}")

            # 4. Safe Data Retrieval
            order_id = clean_row.get('order_id')
            
            if not order_id:
                print(f"Warning: Row {count} missing 'order_id'. Skipping.")
                continue

            # 5. Write to DynamoDB
            table.put_item(Item={
                'order_id': order_id,
                'data':     json.dumps(clean_row),
                'file_key': file_key,
                'processed_at': context.aws_request_id
            })
            count += 1

        # Success Alert
        send_sns_notification(
            topic_arn, 
            "Pipeline Success", 
            f"Successfully processed {count} rows from {file_key}"
        )

        return {'statusCode': 200, 'body': f"Success: {count} rows processed."}

    except Exception as e:
        error_log = f"Critical Error processing {file_key}: {str(e)}"
        print(error_log)

        # Failure Alert
        send_sns_notification(topic_arn, "Pipeline Failed", error_log)
        
        # Re-raise to ensure the Lambda shows as 'Failed' in AWS monitoring
        raise e