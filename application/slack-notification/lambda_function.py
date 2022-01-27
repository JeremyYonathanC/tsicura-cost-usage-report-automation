import json
import urllib.request
import os

webhook_url = os.environ['SLACK_WEBHOOK_URL']
slack_data = {'text': "Hello World"}

def handler(event, context):
    
    if(event["detail"]["status"]=="FAILED"):
        
        slack_data = {"blocks": [{"type": "header","text": {"type": "plain_text","text": ":warning: Step Funcition Failed to Run","emoji": True}},{"type": "divider"},{"type": "section","fields": [{"type": "mrkdwn","text": "*Account ID:*\n"+event["account"]},{"type": "mrkdwn","text": "*Step Function Name:*\n"+"jeremy-testing-CURA"}]},{"type": "section","fields":[ {"type": "mrkdwn","text": "*Status:*\n"+event["detail"]["status"]},{"type": "mrkdwn","text": "*Time:*\n"+ event["time"]}]},{"type": "section","text": {"type": "mrkdwn","text": "*ARN:*\n"+ event["detail"]["stateMachineArn"]}}]}
        req = urllib.request.Request(
            webhook_url, data=json.dumps(slack_data).encode('utf8'),
            headers={'content-type': 'application/json'})
            
        response = urllib.request.urlopen(req)
    
        # print("Test")
    
        # print(json.dumps(event))
        # print(event["detail"]["status"])
    
    if(event["detail"]["status"]=="SUCCEEDED"):
        slack_data= {"blocks": [{"type": "header","text": {"type": "plain_text","text": ":done: Step Funcition Succeeded to Run","emoji": True}},{"type": "divider"},{"type": "section","fields": [{"type": "mrkdwn","text": "*Account ID:*\n"+event["account"]},{"type": "mrkdwn","text": "*Step Function Name:*\n"+"jeremy-testing-CURA"}]},{"type": "section","fields":[ {"type": "mrkdwn","text": "*Status:*\n"+event["detail"]["status"]},{"type": "mrkdwn","text": "*Time:*\n"+ event["time"]}]},{"type": "section","text": {"type": "mrkdwn","text": "*ARN:*\n"+ event["detail"]["stateMachineArn"]}}]}
        req = urllib.request.Request(
            webhook_url, data=json.dumps(slack_data).encode('utf8'),
            headers={'content-type': 'application/json'})
            
        response = urllib.request.urlopen(req)
        
    return {
        "statusCode": 200
    }

    
    