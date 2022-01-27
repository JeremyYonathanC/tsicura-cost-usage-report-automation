import boto3
import csv
import time
import os
import uuid
import datetime
import json
import os

import numpy as np
import pandas as pd

from boto3.session import Session
from retry import retry

from helper import define_google_credentials, create_spreadsheet_for_report, get_sheet_id_by_name, delete_sheet_by_name, update_spreadsheet_data, get_attribute_value, readCSV

from googleapiclient.discovery import build
from google.oauth2 import service_account

GOOGLE_SCOPES = ['https://www.googleapis.com/auth/drive']
GOOGLE_CREDENTIALS_TEMPORARY_JSON = os.environ['google_credentials_temporary_json']
COST_USAGE_REPORT_DIRECTORY_ID = os.environ['cost_usage_report_directory_id']

sts_client = boto3.client('sts')
ssm_client = boto3.client('ssm')

def generate_report(event,s3Client):
    if event['scope'] == "organization":
        return

    google_credentials = service_account.Credentials.from_service_account_file(GOOGLE_CREDENTIALS_TEMPORARY_JSON, scopes=GOOGLE_SCOPES)
    google_drive_service = build('drive', 'v3', credentials=google_credentials, cache_discovery=False)
    google_sheets_service = build('sheets', 'v4', credentials=google_credentials, cache_discovery=False)

    clean_path = event['path'].strip('/').replace('CostUsageReport/', '')
  
    spreadsheet_name = "raw data report "+event['scope']+" "+event['name'].lower() +" "+event['year']+'-'+(event['month'].zfill(2))
    
    event['result'] = {}
    event['result']['spreadsheet_name'] = spreadsheet_name
    event['result']['spreadsheet_path'] = clean_path
    
    google_drive_id = get_attribute_value(event, 'google_drive_id')
  
    spreadsheet_id = create_spreadsheet_for_report(google_drive_service, COST_USAGE_REPORT_DIRECTORY_ID, clean_path, spreadsheet_name, google_drive_id)

    organization_mapping_flag = {}
    organization_mapping_list = []
    
    queryId = event['QueryExecutionId']['QueryExecutionId']
    
    query_response = readCSV(queryId,s3Client)
    
    query_response.replace([np.inf, -np.inf], 0, inplace=True)
    query_response = query_response.fillna("-")
    
    sheet_id_mapping = {}
    sheet_list = [ "report" ]
    
    if event['scope'] == "organization":
        column_list = [ "Cost Category: Organization", "Cost Category: Vertical", "Cost Category: Product", "Cost Category: Product Domain", "Cost Category: Environment", "Infrastructure Type", "Cost Type", "AWS Service", "AWS Usage Type", "Resource Count", "Usage Amount", "Usage Unit", "Unblended Cost", "Amortized Cost", "On-demand Cost" ]
        query_response = query_response.sort_values(by = ['cost_category_organization', 'cost_category_vertical', 'cost_category_product', 'cost_category_product_domain', 'cost_category_environment', 'infrastructure_category', 'pricing_type', 'line_item_product_code', 'line_item_usage_type'])    
    else:
        column_list = [ "Cost Category: Organization", "Cost Category: Vertical", "Cost Category: Product", "Cost Category: Product Domain", "Cost Category: Environment", "Infrastructure Type", "Cost Type", "AWS Service", "Tag: Service", "AWS Usage Type", "Resource Count", "Usage Amount", "Usage Unit", "Unblended Cost", "Amortized Cost", "On-demand Cost" ]
        query_response = query_response.sort_values(by = ['cost_category_organization', 'cost_category_vertical', 'cost_category_product', 'cost_category_product_domain', 'cost_category_environment', 'infrastructure_category', 'pricing_type', 'line_item_product_code', 'resource_tags_user_service', 'line_item_usage_type'])
    
    for sheet_name in sheet_list:
    
        sheet_id_mapping[sheet_name] = {
            "sheet_id": get_sheet_id_by_name(google_sheets_service, spreadsheet_id, sheet_name, True, True),
            "data_rows": []
        }
    
    delete_sheet_by_name(google_sheets_service, spreadsheet_id, "Sheet1")
    
    event['result']['total_number_of_rows'] = len(query_response.index)
    event['result']['spreadsheet_id'] = spreadsheet_id
    
    for sheet_name in sheet_list:
        
        sheet_detail = sheet_id_mapping[sheet_name]
        sheet_detail['data_rows'].append(column_list)
        
        for idx, row in query_response.iterrows():
            if (row['total_unblended_cost'] == 0 and row['total_amortized_cost'] == 0 and row['total_public_cost'] == 0):
                continue
            if event['scope'] == "organization":
                row_item = [
                    row['cost_category_organization'],
                    row['cost_category_vertical'],
                    row['cost_category_product'],
                    row['cost_category_product_domain'],
                    row['cost_category_environment'],
                    row['infrastructure_category'],
                    row['pricing_type'],
                    row['line_item_product_code'],
                    row['line_item_usage_type'],
                    row['resource_count'],
                    row['line_item_usage_amount'],
                    row['pricing_unit'],
                    row['total_unblended_cost'],
                    row['total_amortized_cost'],
                    row['total_public_cost']
                ]
            else:
                row_item = [
                    row['cost_category_organization'],
                    row['cost_category_vertical'],
                    row['cost_category_product'],
                    row['cost_category_product_domain'],
                    row['cost_category_environment'],
                    row['infrastructure_category'],
                    row['pricing_type'],
                    row['line_item_product_code'],
                    row['resource_tags_user_service'],
                    row['line_item_usage_type'],
                    row['resource_count'],
                    row['line_item_usage_amount'],
                    row['pricing_unit'],
                    row['total_unblended_cost'],
                    row['total_amortized_cost'],
                    row['total_public_cost']
                ]
            sheet_detail['data_rows'].append(row_item)
    
    for sheet_name in sheet_list:
        sheet_detail = sheet_id_mapping[sheet_name]
        
        sheet_rows = sheet_detail['data_rows']
       
        update_spreadsheet_data(google_sheets_service, spreadsheet_id, sheet_name, sheet_detail['data_rows'], sheet_id_mapping[sheet_name]['sheet_id'])
    
    return event

def handler(event, context):
    # TODO implement
    google_credentials = define_google_credentials()
    
    s3Client = boto3.client('s3', region_name='us-east-1')
    
    return generate_report(event,s3Client)

if __name__ == "__main__":
    handler(None, None)