import boto3
import csv
import time
import os
import uuid
import datetime
import json

import numpy as np

from boto3.session import Session
from retry import retry
from helper import define_google_credentials, find_directory_id_by_path, readCSV

from googleapiclient.discovery import build
from google.oauth2 import service_account

sts_client = boto3.client('sts')

ASSUME_ROLE_ARN = os.environ['assume_role_arn']
GOOGLE_SCOPES = ['https://www.googleapis.com/auth/drive']
GOOGLE_CREDENTIALS_TEMPORARY_JSON = os.environ['google_credentials_temporary_json']
COST_USAGE_REPORT_DIRECTORY_ID = os.environ['cost_usage_report_directory_id']


def get_org_mapping(event, context, s3Client):
    
    organization_mapping_flag = {}
    organization_mapping_list = []
    
    organization_mapping_flag_deleted = {}
    organization_mapping_list_deleted = []
    
    queryId = event['QueryExecutionId']['QueryExecutionId']
    
    query_response = readCSV(queryId,s3Client)
    
    query_response.replace([np.inf, -np.inf], np.nan, inplace=True)
    query_response = query_response.fillna("")
    
    categories =['organization', 'vertical', 'product', 'product_domain']

    for idx, row in query_response.iterrows():
        organization = row['cost_category_organization']
        vertical = row['cost_category_vertical']
        product = row['cost_category_product']
        product_domain = str(row['cost_category_product_domain'])
        
        year =  datetime.datetime.strptime(event['time'],"%Y-%m-%dT%H:%M:%SZ").strftime("%Y")
        month = datetime.datetime.strptime(event['time'],"%Y-%m-%dT%H:%M:%SZ").strftime("%m")
        
        event['year'] = year
        event['month'] = month
       
        if organization == "":
            organization = "No Cost Category: Organization"
        
        if vertical == "":
            vertical = "No Cost Category: Vertical"
        
        if product == "":
            product = "No Cost Category: Product"

        if product_domain == "":
            product_domain = "No Cost Category: Product Domain"

        for category in categories:
            
            try:
                if category=='organization':
                    key = "/CostUsageReport/organization/"+organization+"/report/year=" + year + "/month=" + month + "/"
                    key_deleted = "/CostUsageReport/organization/"+organization+"/report/year=" + year + "/month=01/"     
                    temporary = organization         
                if category=='vertical':
                    key = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/report/year=" + year + "/month=" + month + "/"
                    key_deleted = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/report/year=" + year + "/month=01/"
                    temporary = vertical
                if category=='product':
                    key = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/product/" + product + "/report/year=" + year + "/month=" + month + "/"
                    key_deleted = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/product/" + product + "/report/year=" + year + "/month=01/"
                    temporary = product
                if category=='product_domain':
                    key = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/product/" + product + "/product-domain/" + product_domain + "/report/year=" + year + "/month=" + month + "/"
                    key_deleted = "/CostUsageReport/organization/"+organization+"/vertical/" + vertical + "/product/" + product + "/product-domain/" + product_domain + "/report/year=" + year + "/month=01/"
                    temporary = product_domain
                try:
                    temp = organization_mapping_flag[key]
                    temp_deleted = organization_mapping_flag_deleted[key_deleted]
                except:
                    organization_mapping_flag[key] = len(organization_mapping_list)
                    if category!='product_domain' :
                        organization_mapping_list.append({
                            "scope": category,
                            "month": month,
                            "year": year,
                            "name": temporary,
                            # "organization": organization,
                            "path": key,
                            "pd_list": []
                        })
                        organization_mapping_flag_deleted[key_deleted] = len(organization_mapping_list_deleted)
                        organization_mapping_list_deleted.append({
                            "scope": category,
                            "month": month,
                            "year": year,
                            "name": temporary,
                            # "organization": organization,
                            "path": key_deleted,
                            "pd_list": []
                        })
                    else:
                        organization_mapping_list.append({
                            "scope": 'product-domain',
                            "month": month,
                            "year": year,
                            "name": temporary,
                            # "organization": organization,
                            "path": key,
                            'product':product,
                            "pd_list": [product_domain]
                        })
                        organization_mapping_flag_deleted[key_deleted] = len(organization_mapping_list_deleted)
                        organization_mapping_list_deleted.append({
                            "scope": category,
                            "month": month,
                            "year": year,
                            "name": temporary,
                            # "organization": organization,
                            "path": key_deleted,
                            'product':product,
                            "pd_list": [product_domain]
                        })
                if category=='organization' or category=='product':
                    organization_mapping_list[organization_mapping_flag[key]]['pd_list'].append(product_domain)
                    organization_mapping_list_deleted[organization_mapping_flag_deleted[key_deleted]]['pd_list'].append(product_domain)
                if category=='vertical':
                    organization_mapping_list_deleted[organization_mapping_flag_deleted[key_deleted]]['pd_list'].append(product_domain_key)
            except:
                # print("skipped" +category+":")
                pass
        
    google_credentials = service_account.Credentials.from_service_account_file(GOOGLE_CREDENTIALS_TEMPORARY_JSON, scopes=GOOGLE_SCOPES)
    google_drive_service = build('drive', 'v3', credentials=google_credentials, cache_discovery=False)

    print("Generating "+str(len(organization_mapping_list))+" path")
    
    for data in organization_mapping_list:
        curr_path = data['path'].strip('/')
        curr_path = curr_path.replace('CostUsageReport/', '')

### 16        
        data['google_drive_id'] = find_directory_id_by_path(google_drive_service, COST_USAGE_REPORT_DIRECTORY_ID, curr_path, curr_path, "")

### 18    
    return {
        "generation_id": str(uuid.uuid4()),
        "start_time": "temp",
        "end_time": "temp",
        "items": organization_mapping_list
    }
    
    


def handler(event, context):

    startTime = datetime.datetime.now()

    google_credentials = define_google_credentials()

    print(google_credentials)
    
    s3Client = boto3.client('s3', region_name='us-east-1')
  
    orgMapping = get_org_mapping(event, context,s3Client)
    
    orgMapping['start_time'] = str(startTime)
    orgMapping['end_time'] = str(datetime.datetime.now())

    return orgMapping

if __name__ == "__main__":
    handler(None, None)
