def get_query_string(scope):
    query_string = ""
    with open('query_get_export_by_product_domain.sql', 'r') as file:
        query_string = file.read()
    return query_string
    
def get_attribute_value(obj, attribute):
    try:
        return obj[attribute]
    except:
        return ""