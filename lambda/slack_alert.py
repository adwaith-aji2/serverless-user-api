import json
import os
import urllib3

http = urllib3.PoolManager()
SLACK_WEBHOOK = os.environ['SLACK_WEBHOOK_URL']

def lambda_handler(event, context):
    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])
        alert_text = f"ALERT: {message.get('AlarmName')} triggered\nStatus: {message.get('NewStateValue')}\nReason: {message.get('NewStateReason')}"
        
        payload = {"text": alert_text}
        encoded_data = json.dumps(payload).encode('utf-8')
        resp = http.request('POST', SLACK_WEBHOOK, body=encoded_data, headers={'Content-Type': 'application/json'})
        
    return {"status": "ok"}
