import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    body = json.loads(event['body'])
    user_id = body['id']
    table.put_item(Item=body)
    
    return {
        'statusCode': 201,
        'body': json.dumps({'message': f'User {user_id} created'})
    }
