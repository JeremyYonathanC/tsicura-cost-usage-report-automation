import json

from helper import \
    get_query_string, \
    get_attribute_value

def handler(event, context):
    # TODO implement
    
    event['result'] = {}
    query_string = get_query_string(event['scope'])
    
    if query_string == "":
        print("error: query_string variable is empty!")
        return
    
    idx = 0
    for row in event['pd_list']:
        if row == "No Cost Category: Product Domain":
            event['pd_list'][idx] = ""
        idx = idx + 1
    
    if event['scope'] == "organization":
        query_string = query_string.replace('"""organization"""', event['name'])

    query_string = query_string.replace('"""pd"""', "'"+("', '".join(event['pd_list']))+"'")
    query_string = query_string.replace('"""year"""', event['year'])
    query_string = query_string.replace('"""month"""', event['month'])
    
    additional_condition = ""
    
    if get_attribute_value(event, 'product') != "":
        if get_attribute_value(event, 'product') == "No Cost Category: Product":
            event['product'] = ""
        additional_condition = additional_condition + "AND cost_category_product = '"+event['product']+"' "
    
    if get_attribute_value(event, 'vertical') != "":
        if get_attribute_value(event, 'vertical') == "No Cost Category: Vertical":
            event['vertical'] = ""
        additional_condition = additional_condition + "AND cost_category_vertical = '"+event['vertical']+"' "
 
    if get_attribute_value(event, 'organization') != "":
        if get_attribute_value(event, 'organization') == "No Cost Category: Organization":
            event['organization'] = ""
        additional_condition = additional_condition + "AND cost_category_organization = '"+event['organization']+"' "

    query_string = query_string.replace('"""additional_condition"""', additional_condition)
    
    event['result']['query_string'] = query_string
    
    return (event)
    



