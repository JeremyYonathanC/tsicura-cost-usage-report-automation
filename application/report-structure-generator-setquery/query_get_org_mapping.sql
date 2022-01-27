SELECT
    cost_category_organization,
    cost_category_vertical,
    cost_category_product,
    cost_category_product_domain
FROM hourly_datarefresh_parquet_dev2
WHERE year = '2022' AND cost_category_organization != ''
GROUP BY 
    cost_category_organization,
    cost_category_vertical,
    cost_category_product,
    cost_category_product_domain