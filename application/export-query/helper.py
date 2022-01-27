import os
import boto3
import json
import math
import pandas as pd

from retry import retry
from boto3.dynamodb.conditions import Key

ssm_client = boto3.client('ssm')

dynamodb_resource = boto3.resource('dynamodb')
dynamodb_table = dynamodb_resource.Table(os.environ['path_cache_table_name'])
ATHENA_S3_BUCKET_QUERY_RESULT = os.environ['athena_s3_bucket_query_result']
GOOGLE_CREDENTIALS_SSM_PATH = os.environ['google_credentials_ssm_path']
GOOGLE_CREDENTIALS_TEMPORARY_JSON = os.environ['google_credentials_temporary_json']

def define_google_credentials():
    parameter = ssm_client.get_parameter(Name=GOOGLE_CREDENTIALS_SSM_PATH, WithDecryption=True)
    credential_data = json.loads(parameter['Parameter']['Value'])
    with open(GOOGLE_CREDENTIALS_TEMPORARY_JSON, 'w') as outfile:
        json.dump(credential_data, outfile)
    return credential_data
    
def get_attribute_value(obj, attribute):
    try:
        return obj[attribute]
    except:
        return ""
        
def create_spreadsheet_for_report(service, parentId, path, name, directory_id):
    if directory_id == None:

        directory_id = find_directory_id_by_path(service, parentId, path, path, "")

    directory_listing = service.files().list(
        q = "parents in '" + directory_id + "'", 
        pageSize=100, 
        fields="nextPageToken, files(id, name)"
    ).execute()
    
    spreadsheet_id = None
    for dir_result in directory_listing['files']:
        if dir_result['name'] == name:
            spreadsheet_id = dir_result['id']
    
    if spreadsheet_id == None:
        spreadsheet = service.files().create(body={
            'name': name,
            'mimeType': 'application/vnd.google-apps.spreadsheet',
            'parents': [directory_id]
        }, fields='id').execute()
        
        spreadsheet_id = spreadsheet.get('id')
    
    return spreadsheet_id
    
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
        with dynamodb_table.batch_writer() as batch:
            batch.put_item(
                Item = {
                    'path': originalPath,
                    'id': child_match_id
                }
            )
            batch.put_item(
                Item = {
                    'path': currParentPath,
                    'id': parentId
                }
            )
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


def get_sheet_id_by_name(service, spreadsheet_id, name, create_if_none, clear_sheet):
    sheet_id = None
    spreadsheet = service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()

    for _sheet in spreadsheet['sheets']:
        if _sheet['properties']['title'] == name:
            sheet_id = str(_sheet['properties']['sheetId'])

    if sheet_id == None and create_if_none == True:
        response = service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={ 'requests': [{ 'addSheet': { 'properties': { 'title': name } } }] }
        ).execute()
        sheet_id = response['replies'][0]['addSheet']['properties']['sheetId']

    if clear_sheet == True:
        service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={ 'requests': [{ 'updateCells': { 'range': { 'sheetId': sheet_id }, 'fields': "userEnteredValue" } }] }
        ).execute()

    return sheet_id


def delete_sheet_by_name(service, spreadsheet_id, name):
    sheet_id = None
    spreadsheet = service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
    
    for _sheet in spreadsheet['sheets']:
        if _sheet['properties']['title'] == name:
            sheet_id = str(_sheet['properties']['sheetId'])

    if sheet_id != None:
        service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={ 'requests': [{ 'deleteSheet': { 'sheetId': sheet_id } }] }
        ).execute()
        
def update_spreadsheet_data(service, spreadsheet_id, sheet_name, sheet_rows, sheet_id):
    
    total_number_of_row = len(sheet_rows)
    per_page = 1000
    row_start = 1
    total_number_of_page = math.ceil(total_number_of_row / per_page)
    
    sheet_rows[0].append('')

    for rows in range(int(total_number_of_page)+1):
        
        start = rows * per_page
        
        last_index = start + per_page
        
        if last_index > total_number_of_row:
            last_index = total_number_of_row

        start_cells = "A"+str(row_start + start)
        
        batch_list_arrays = []
        
        for idx in range(start, last_index):
            batch_list_arrays.append(sheet_rows[idx])
            

        service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id, 
            range=sheet_name+'!'+start_cells+':H', 
            valueInputOption='USER_ENTERED',
            insertDataOption='INSERT_ROWS', 
            body={
                "range": sheet_name+'!'+start_cells+':H', 
                "values": batch_list_arrays
            }
        ).execute()
    
    try:
        service.spreadsheets().batchUpdate(
            spreadsheetId=spreadsheet_id,
            body={ 'requests': [
                { 'deleteDimension': { 'range': { 'sheetId': sheet_id, 'dimension': 'COLUMNS', 'startIndex': len(sheet_rows[0]) - 1, 'endIndex': 100 } } },
                { 'deleteDimension': { 'range': { 'sheetId': sheet_id, 'dimension': 'ROWS', 'startIndex': total_number_of_row + 1, 'endIndex': total_number_of_row * 100 } } }
            ] }
        ).execute()
    except:
        print("error on update_spreadsheet_data while clearing sheet")
        pass

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