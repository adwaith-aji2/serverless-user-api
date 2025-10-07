import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    user_id = event['pathParameters']['id']
    table.delete_item(Key={'id': user_id})
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'User {user_id} deleted'})
    }
