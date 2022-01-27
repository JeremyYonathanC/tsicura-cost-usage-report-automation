import json

def handler(event, context):

    query_string = ""
    with open('query_get_org_mapping.sql', 'r') as file:
        query_string = file.read()

    if query_string == "":
        print("error: query_string variable is empty!")
        return
    
    event['query_string']= query_string
  
    
    return event