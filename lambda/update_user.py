import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    user_id = event['pathParameters']['id']
    body = json.loads(event['body'])
    
    update_expression = "SET "
    expression_attributes = {}
    for key, value in body.items():
        update_expression += f"{key} = :{key}, "
        expression_attributes[f":{key}"] = value
    update_expression = update_expression.rstrip(", ")
    
    table.update_item(
        Key={'id': user_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_attributes
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'User {user_id} updated'})
    }
