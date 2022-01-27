import os
import boto3
import json
import math
import pandas as pd

from retry import retry

ssm_client = boto3.client('ssm')

dynamodb_resource = boto3.resource('dynamodb')
dynamodb_table = dynamodb_resource.Table(os.environ['path_cache_table_name'])
ATHENA_S3_BUCKET_QUERY_RESULT = os.environ['athena_s3_bucket_query_result']
GOOGLE_CREDENTIALS_SSM_PATH = os.environ['google_credentials_ssm_path']
GOOGLE_CREDENTIALS_TEMPORARY_JSON = os.environ['google_credentials_temporary_json']

def find_directory_id_by_path(service, parentId, path, originalPath, parentPath):

    super_parent_path = path.split('/')
    popped_super_parent = super_parent_path.pop()
    super_parent_path = "/".join(super_parent_path)

    super_parent_id = None
    try:
        table_response = dynamodb_table.get_item(Key= { 'path': super_parent_path })
        super_parent_id = table_response['Item']['id']
    except:
        pass


    try:
        table_response = dynamodb_table.get_item(Key= { 'path': path })
        return table_response['Item']['id']
    except:
        pass
    
    path_splitted = path.split('/')
    child_match = path_splitted[0] 

    if super_parent_id != None:
        path_splitted = [popped_super_parent]
        child_match = popped_super_parent
        parentId = super_parent_id

    directory_listing = service.files().list(
        q = "parents in '" + parentId + "'", 
        pageSize=100, 
        fields="nextPageToken, files(id, name)"
    ).execute()
    

    parentPath = parentPath.split('/')
    parentPath.append(child_match)
    parentPath = "/".join(parentPath)
    
    is_final_path = False
    if len(path_splitted) == 1:
        is_final_path = True
    
    child_match_id = None
    for dir_result in directory_listing['files']:
        if dir_result['name'] == child_match:
            child_match_id = dir_result['id']
    
    if is_final_path == True and child_match_id == None:
        file = service.files().create(body={
            'name': child_match,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [parentId]
        }, fields='id').execute()
        return file.get('id')
    
    if is_final_path == True and child_match_id != None:
        currParentPath = originalPath.split('/')
        currParentPath.pop()
        currParentPath  = "/".join(currParentPath)
        # with dynamodb_table.batch_writer() as batch:
        #     batch.put_item(
        #         Item = {
        #             'path': originalPath,
        #             'id': child_match_id
        #         }
        #     )
        #     batch.put_item(
        #         Item = {
        #             'path': currParentPath,
        #             'id': parentId
        #         }
        #     )
        return child_match_id
    
    if child_match_id:
        return find_directory_id_by_path(service, child_match_id, path.replace(child_match + '/',''), originalPath, parentPath)
    else:
        file = service.files().create(body={
            'name': child_match,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [parentId]
        }, fields='id').execute()
        parentPathId = file.get('id')
        return find_directory_id_by_path(service, parentPathId, path.replace(child_match + '/',''), originalPath, parentPath)



def define_google_credentials():
    parameter = ssm_client.get_parameter(Name=GOOGLE_CREDENTIALS_SSM_PATH, WithDecryption=True)
    credential_data = json.loads(parameter['Parameter']['Value'])
    with open(GOOGLE_CREDENTIALS_TEMPORARY_JSON, 'w') as outfile:
        json.dump(credential_data, outfile)
    return credential_data
    
    
def readCSV(queryId,s3Client):
    print("downloading: "+ATHENA_S3_BUCKET_QUERY_RESULT + "/1/Unsaved/2022/01/10/" + queryId + ".csv")
    object_response = s3Client.get_object(
        Bucket = ATHENA_S3_BUCKET_QUERY_RESULT,
        Key = "1/Unsaved/2022/01/10/" + queryId + ".csv"
    )
    
    # 1/Unsaved/2022/01/05/05c74487-771d-4132-a304-8df24c1b47ca.csv
    
    object_content = object_response['Body'].read()
    with open("/tmp/"+ queryId + ".csv", 'wb') as file:
        file.write(object_content)

    return pd.read_csv("/tmp/"+ queryId + ".csv")
    