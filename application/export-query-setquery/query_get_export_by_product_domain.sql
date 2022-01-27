WITH final_presentation AS (
	WITH xyz AS (

	    SELECT -- Note: This select gets all columns except EDP Discount
	    ---JEREMY YONATHAN CHRISYANO

	    	COALESCE(CASE 
	    		WHEN line_item_line_item_type = 'RiVolumeDiscount' AND line_item_usage_account_id IN ('413556954708', '811468751499', '043375393462', '146534595588', '536507027298')
	    		THEN 'org'
	    		WHEN line_item_line_item_type = 'RiVolumeDiscount' AND line_item_usage_account_id IN ('015110552125')
	    		THEN 'bei'
	    		WHEN line_item_line_item_type = 'RiVolumeDiscount' AND line_item_usage_account_id IN ('927026143189')
	    		THEN 'din'
	    		ELSE cost_category_product_domain
	    	END, '') AS "cost_category_product_domain", -- OK

			cost_category_vertical,
			cost_category_organization,
			cost_category_product,
			cost_category_environment,
			line_item_usage_type,
			resource_tags_user_service,
			pricing_unit,
			line_item_product_code,

			SUM(line_item_unblended_cost) + SUM(CASE 
				WHEN line_item_usage_account_id NOT IN ('927026143189', '015110552125', '413556954708', '811468751499', '043375393462', '146534595588', '536507027298', '743977200366', '034455779033', '517530806209', '715824975366') THEN
					discount_total_discount
				ELSE 0.0 
			END) AS line_item_unblended_cost,

			SUM(CASE WHEN line_item_line_item_type IN ('DiscountedUsage', 'Usage', 'SavingsPlanCoveredUsage') AND line_item_product_code != 'AWSDeveloperSupport' THEN 
				(
	                CASE WHEN line_item_line_item_type = 'DiscountedUsage' THEN
	                    pricing_public_on_demand_cost
	                ELSE
	                    0.0
	                END
	            ) + 
	            (
	                CASE WHEN line_item_line_item_type = 'Usage' THEN
	                    line_item_unblended_cost
	                ELSE
	                    0.0
	                END
	            ) + 
	            (
	                CASE WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN
	                    line_item_unblended_cost
	                ELSE
	                    0.0
	                END
	            )
	        ELSE 0.0 END) AS total_public_cost,

	        SUM(CASE WHEN 
	                line_item_line_item_type = 'Usage' AND line_item_usage_type != 'Dollar' 
	            THEN line_item_unblended_cost 
	            ELSE 0 END
	        ) AS "usage", -- OK
	        
	        SUM(reservation_effective_cost) AS "reservation_applied_usage", -- OK

	        0 AS "upfront_reservation_fee", -- OK for now; This is always 0

	        SUM(reservation_unused_amortized_upfront_fee_for_billing_period) + SUM(reservation_unused_recurring_fee) AS "recurring_reservation_fee", -- OK
	        SUM(savings_plan_savings_plan_effective_cost) AS "savings_plans_covered_usage", -- OK; The proportion of the Savings Plan monthly commitment amount (Upfront and recurring) that is allocated to each usage line. 
	        
	        0 AS "savings_plans_recurring_fees", -- OK for now; This is always 0  
	        
	        SUM(CASE WHEN 
	                line_item_usage_type = 'Route53-Domains' OR (
	                    line_item_usage_type LIKE '%-OCB' AND line_item_line_item_type='Fee'
	                ) 
	            THEN line_item_unblended_cost 
	            ELSE 0 
	        END) AS "other_out_of_cycle_charges", -- TODO

	        SUM(CASE
	            WHEN (CASE 
	                WHEN line_item_line_item_type = 'Usage' AND line_item_usage_type = 'Dollar' THEN 'included'
	                WHEN line_item_line_item_type = 'Fee' AND line_item_usage_type = '' THEN 'included' 
	                WHEN line_item_line_item_type = 'Fee' AND line_item_usage_type = 'Dollar' THEN 'included'
	                END = 'included') THEN line_item_unblended_cost 
	            ELSE 0 
	        END) AS "support_fee", -- OK

	        SUM(CASE WHEN line_item_line_item_type = 'Tax' AND line_item_usage_type != 'Dollar' THEN line_item_unblended_cost ELSE 0 END) AS "tax", -- OK
	        SUM(CASE WHEN line_item_line_item_type = 'RiVolumeDiscount' THEN line_item_unblended_cost ELSE 0 END) AS "ri_volume_discount", -- TODO

	        0 AS "savings_plans_negation", -- OK for now; This is always 0 

	        SUM(CASE WHEN line_item_line_item_type = 'Credit' THEN line_item_unblended_cost ELSE 0 END) AS "credit", -- TODO
	        SUM(CASE WHEN line_item_line_item_type = 'Refund' THEN line_item_unblended_cost ELSE 0 END) AS "refund"

	    FROM hourly_datarefresh_parquet_dev2 
	    WHERE month = '"""month"""' AND year = '"""year"""' """additional_condition"""
	    GROUP BY 
	        cost_category_product_domain, 
	        line_item_line_item_type, 
	        line_item_usage_type,
	        1,
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product
		HAVING cost_category_product_domain IN ("""pd""")
	), support_discount AS (
	    SELECT  
	        cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product,
			cost_category_environment,
			line_item_usage_type,
			resource_tags_user_service,
			pricing_unit,
			line_item_product_code,
	        (0 - ((SUM(line_item_unblended_cost) * 13) / 100)) AS support_discount
	    FROM 
	        hourly_datarefresh_parquet_dev2
	    WHERE
	        year = '"""year"""' AND
	        month = '"""month"""' AND
	        line_item_usage_account_id NOT IN ('927026143189', '015110552125', '413556954708', '811468751499', '043375393462', '146534595588', '536507027298', '743977200366', '034455779033', '517530806209', '715824975366') AND
	        line_item_product_code IN ('AWSDeveloperSupport') AND 
	        line_item_line_item_type = 'Fee' AND
	        cost_category_product_domain NOT IN ('din', 'bei', 'org') AND 
			cost_category_product_domain IN ("""pd""")
	    GROUP BY 
	        cost_category_product_domain,
			cost_category_organization,
			line_item_usage_type,
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
			cost_category_vertical,
			cost_category_product
	), edp_discount AS (

		WITH summary_edp_shared_account AS (
		    WITH flag_attribute AS (
				SELECT DISTINCT
						line_item_usage_account_id,
						line_item_usage_type,
						resource_tags_user_service,
						cost_category_environment,
						pricing_unit,
						line_item_product_code,
						(CASE WHEN 
							line_item_line_item_type = 'Fee' THEN 1
						ELSE 0 END) AS is_fee_exists,
						(CASE WHEN 
							line_item_line_item_type = 'RIFee' THEN 1
						ELSE 0 END) AS is_ri_fee_exists
					FROM 
						hourly_datarefresh_parquet_dev2
					WHERE
						year = '"""year"""' AND
						month = '"""month"""'
					GROUP BY
						line_item_usage_account_id,
						line_item_line_item_type,
						line_item_usage_type,
						resource_tags_user_service,
						cost_category_environment,
						pricing_unit,
						line_item_product_code
		    )
		    SELECT  
		        CASE 
		            WHEN line_item_usage_account_id = '927026143189' THEN 'din'
		            WHEN line_item_usage_account_id = '015110552125' THEN 'bei'
		            WHEN line_item_usage_account_id IN ('413556954708', '811468751499', '043375393462', '146534595588', '536507027298') THEN 'org'
		            WHEN line_item_usage_account_id IN ('743977200366', '034455779033', '517530806209', '715824975366') THEN ''
		            ELSE ''
		        END AS cost_category_product_domain,
				cost_category_organization,
				cost_category_vertical,
				cost_category_product,
				cost_category_environment,
		        line_item_usage_type,
				resource_tags_user_service,
				pricing_unit,
				line_item_product_code,
		        SUM(CASE 
		            WHEN 
		                (
							SELECT SUM(is_fee_exists) 
							FROM flag_attribute 
							WHERE 
								flag_attribute.line_item_usage_type = hourly_datarefresh_parquet_dev2.line_item_usage_type AND 
								flag_attribute.line_item_usage_account_id = hourly_datarefresh_parquet_dev2.line_item_usage_account_id AND 
								flag_attribute.resource_tags_user_service = hourly_datarefresh_parquet_dev2.resource_tags_user_service AND 
								flag_attribute.cost_category_environment = hourly_datarefresh_parquet_dev2.cost_category_environment AND 
								flag_attribute.pricing_unit = hourly_datarefresh_parquet_dev2.pricing_unit AND 
								flag_attribute.line_item_product_code = hourly_datarefresh_parquet_dev2.line_item_product_code
						) = 1 AND
		                (
							SELECT SUM(is_ri_fee_exists) 
							FROM flag_attribute 
							WHERE 
								flag_attribute.line_item_usage_type = hourly_datarefresh_parquet_dev2.line_item_usage_type AND 
								flag_attribute.line_item_usage_account_id = hourly_datarefresh_parquet_dev2.line_item_usage_account_id AND 
								flag_attribute.resource_tags_user_service = hourly_datarefresh_parquet_dev2.resource_tags_user_service AND 
								flag_attribute.cost_category_environment = hourly_datarefresh_parquet_dev2.cost_category_environment AND 
								flag_attribute.pricing_unit = hourly_datarefresh_parquet_dev2.pricing_unit AND 
								flag_attribute.line_item_product_code = hourly_datarefresh_parquet_dev2.line_item_product_code
						) = 1 AND
		                line_item_line_item_type = 'RIFee'
		                THEN
		                    discount_total_discount
		            WHEN
		                (
							SELECT SUM(is_fee_exists) 
							FROM flag_attribute 
							WHERE 
								flag_attribute.line_item_usage_type = hourly_datarefresh_parquet_dev2.line_item_usage_type AND 
								flag_attribute.line_item_usage_account_id = hourly_datarefresh_parquet_dev2.line_item_usage_account_id AND 
								flag_attribute.resource_tags_user_service = hourly_datarefresh_parquet_dev2.resource_tags_user_service AND 
								flag_attribute.cost_category_environment = hourly_datarefresh_parquet_dev2.cost_category_environment AND 
								flag_attribute.pricing_unit = hourly_datarefresh_parquet_dev2.pricing_unit AND 
								flag_attribute.line_item_product_code = hourly_datarefresh_parquet_dev2.line_item_product_code
						) = 0 AND
		                line_item_line_item_type = 'EdpDiscount'
		                THEN 
		                    line_item_unblended_cost
		            ELSE 0
		        END) AS edp_discount_final 
		    FROM 
		        hourly_datarefresh_parquet_dev2
		    WHERE
		        year = '"""year"""' AND
		        month = '"""month"""' AND
		        line_item_usage_account_id IN ('927026143189', '015110552125', '413556954708', '811468751499', '043375393462', '146534595588', '536507027298', '743977200366', '034455779033', '517530806209', '715824975366')
		    GROUP BY
		        line_item_usage_type,
		        line_item_line_item_type,
		        1,
				cost_category_product_domain,
				cost_category_organization,
				resource_tags_user_service,
				cost_category_environment,
				cost_category_vertical,
				cost_category_product,
				pricing_unit,
				line_item_product_code
			HAVING cost_category_product_domain IN ("""pd""")
		)
		SELECT  
		    cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product,
			line_item_usage_type, 
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
		    SUM(discount_edp_discount) AS edp_discount
		FROM 
		    hourly_datarefresh_parquet_dev2
		WHERE
		    year = '"""year"""' AND
		    month = '"""month"""' AND
		    line_item_usage_account_id NOT IN ('927026143189', '015110552125', '413556954708', '811468751499', '043375393462', '146534595588', '536507027298', '743977200366', '034455779033', '517530806209', '715824975366') AND
		    cost_category_product_domain NOT IN ('din', 'bei', 'org')
		GROUP BY
		    cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			line_item_usage_type,
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
			cost_category_product
		UNION
		SELECT
		    cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product,
			line_item_usage_type,
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
		    SUM(edp_discount_final) AS edp_discount
		FROM summary_edp_shared_account
		GROUP BY
		    cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			line_item_usage_type,
			resource_tags_user_service,
			cost_category_environment,
			pricing_unit,
			line_item_product_code,
			cost_category_product
		ORDER BY
		    edp_discount
	)
	SELECT 
	    CASE WHEN xyz.cost_category_product_domain = '' THEN 'No Cost Category: Product Domain' ELSE xyz.cost_category_product_domain END as cost_category_product_domain,
		cost_category_organization,
		cost_category_vertical,
		cost_category_product,
		cost_category_environment,
		(
			CASE
				WHEN
					line_item_usage_type = 'APS1-NatGateway-Hours' OR
					line_item_usage_type = 'APS1-VpcEndpoint-Hours' OR
					line_item_usage_type = 'APS1-VpcEndpoint-Bytes' OR
					line_item_usage_type = 'APS1-NatGateway-Bytes' OR
					line_item_usage_type = 'APS1-DataProcessing-Bytes' OR
					line_item_usage_type = 'APS1-VendedLog-Bytes' OR
					line_item_usage_type = 'APS1-CW:MetricMonitorUsage' OR
					line_item_usage_type = 'APS1-TimedStorage-ByteHrs' OR
					line_item_usage_type = 'WebACL' OR
					line_item_usage_type = 'Rule' OR
					line_item_usage_type = 'Dollar' OR
					line_item_usage_type = 'APS1-ConfigurationItemRecorded'
				THEN
					'Scaffolding'
				ELSE
					'Application'
			END
		) as "infrastructure_category",
		(
			CASE
				WHEN
					pricing_unit = 'Hrs'
				THEN
					'Fixed'
				ELSE
					'Variable'
			END
		) as "pricing_type",
		line_item_product_code,
		resource_tags_user_service,
		line_item_usage_type,
		pricing_unit,
		ROUND(SUM(xyz.line_item_unblended_cost), 2) as "total_unblended_cost",
		ROUND(SUM(xyz.total_public_cost), 2) as "total_public_cost",
		ROUND(
			SUM(xyz.usage) +
			SUM(xyz.reservation_applied_usage) +
			SUM(xyz.upfront_reservation_fee) +
			SUM(xyz.recurring_reservation_fee) +
			SUM(xyz.savings_plans_covered_usage) +
			SUM(xyz.savings_plans_recurring_fees) +
			SUM(xyz.other_out_of_cycle_charges) +
			SUM(xyz.support_fee) +
			SUM(xyz.tax) +
			SUM(xyz.ri_volume_discount) +
			SUM(xyz.savings_plans_negation) + 
			SUM(xyz.credit) +
			SUM(xyz.refund) +
			(
				COALESCE((
					SELECT SUM(support_discount) FROM support_discount 
					WHERE 
						support_discount.cost_category_product_domain = xyz.cost_category_product_domain AND 
						support_discount.cost_category_organization = xyz.cost_category_organization AND 
						support_discount.cost_category_vertical = xyz.cost_category_vertical AND 
						support_discount.cost_category_product = xyz.cost_category_product AND 
						support_discount.line_item_usage_type = xyz.line_item_usage_type AND 
						support_discount.resource_tags_user_service = xyz.resource_tags_user_service AND 
						support_discount.cost_category_environment = xyz.cost_category_environment AND 
						support_discount.pricing_unit = xyz.pricing_unit AND 
						support_discount.line_item_product_code = xyz.line_item_product_code
				), 0) + COALESCE((
					SELECT SUM(edp_discount) FROM edp_discount 
					WHERE 
						edp_discount.cost_category_product_domain = xyz.cost_category_product_domain AND 
						edp_discount.cost_category_organization = xyz.cost_category_organization AND 
						edp_discount.cost_category_vertical = xyz.cost_category_vertical AND 
						edp_discount.cost_category_product = xyz.cost_category_product AND 
						edp_discount.line_item_usage_type = xyz.line_item_usage_type AND 
						edp_discount.resource_tags_user_service = xyz.resource_tags_user_service AND 
						edp_discount.cost_category_environment = xyz.cost_category_environment AND 
						edp_discount.pricing_unit = xyz.pricing_unit AND 
						edp_discount.line_item_product_code = xyz.line_item_product_code
				), 0)
		), 2) AS "total_amortized_cost"
		
	FROM xyz
	WHERE xyz.cost_category_product_domain IN ("""pd""")
	GROUP BY 
		xyz.cost_category_product_domain,
		xyz.line_item_usage_type,
		xyz.resource_tags_user_service,
		xyz.cost_category_environment,
		xyz.pricing_unit,
		xyz.line_item_product_code,
		xyz.cost_category_organization,
		xyz.cost_category_vertical,
		xyz.cost_category_product
), compiled_resources_counter as (
	WITH raw_data_resources as (
	    SELECT
	        line_item_product_code,
	        line_item_resource_id,
	        line_item_usage_type,
	        resource_tags_user_service,
	        pricing_unit,
	        SUM(line_item_usage_amount) as line_item_usage_amount,
	        cost_category_environment,
	        (
	            CASE WHEN (length(line_item_product_code)=25) THEN
	                CASE WHEN LOWER(line_item_product_code) not LIKE 'aws%' and LOWER(line_item_product_code) not LIKE 'amazon%' THEN
	                    product_product_name
	                END
	            ELSE
	                line_item_product_code
	            END
	        ) as aws_service_name,
	        (
	            CASE
	                WHEN
	                    pricing_unit = 'Hrs'
	                THEN
	                    'Fixed'
	                ELSE
	                    'Variable'
	            END
	        ) as "pricing_type",
	        (
	            CASE
	                WHEN
	                    line_item_usage_type = 'APS1-NatGateway-Hours' OR
	                    line_item_usage_type = 'APS1-VpcEndpoint-Hours' OR
	                    line_item_usage_type = 'APS1-VpcEndpoint-Bytes' OR
	                    line_item_usage_type = 'APS1-NatGateway-Bytes' OR
	                    line_item_usage_type = 'APS1-DataProcessing-Bytes' OR
	                    line_item_usage_type = 'APS1-VendedLog-Bytes' OR
	                    line_item_usage_type = 'APS1-CW:MetricMonitorUsage' OR
	                    line_item_usage_type = 'APS1-TimedStorage-ByteHrs' OR
	                    line_item_usage_type = 'WebACL' OR
	                    line_item_usage_type = 'Rule' OR
	                    line_item_usage_type = 'Dollar' OR
	                    line_item_usage_type = 'APS1-ConfigurationItemRecorded'
	                THEN
	                    'Scaffolding'
	                ELSE
	                    'Application'
	            END
	        ) as "infrastructure_category",
	        cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product
	    FROM
	        hourly_datarefresh_parquet_dev2
	    WHERE
	        cost_category_product_domain IN ("""pd""") AND year = '"""year"""' AND month = '"""month"""'
	        AND line_item_resource_id != ''
	    GROUP BY
	        10,
	        8,
	        line_item_product_code,
	        resource_tags_user_service,
	        cost_category_environment,
	        line_item_resource_id,
	        pricing_unit,
	        line_item_usage_type,
	        cost_category_product_domain,
			cost_category_organization,
			cost_category_vertical,
			cost_category_product
	)
	SELECT
	    line_item_product_code,
	    resource_tags_user_service,
	    line_item_usage_type,
	    cost_category_environment,
	    pricing_unit,
	    infrastructure_category,
	    pricing_type,
	    COUNT(line_item_resource_id) as service_count,
	    SUM(line_item_usage_amount) as line_item_usage_amount,
	    aws_service_name,
	    cost_category_product_domain,
		cost_category_organization,
		cost_category_vertical,
		cost_category_product
	FROM
	    raw_data_resources
	GROUP BY
	    line_item_product_code,
	    cost_category_environment,
	    aws_service_name,
	    line_item_usage_type,
	    resource_tags_user_service,
	    pricing_unit,
	    infrastructure_category,
	    pricing_type,
	    cost_category_product_domain,
		cost_category_organization,
		cost_category_vertical,
		cost_category_product
)
SELECT 
	CASE WHEN cost_category_organization = '' THEN 'No Cost Category: Organization' ELSE cost_category_organization END as cost_category_organization,
	CASE WHEN cost_category_vertical = '' THEN 'No Cost Category: Vertical' ELSE cost_category_vertical END as cost_category_vertical,
	CASE WHEN cost_category_product = '' THEN 'No Cost Category: Product' ELSE cost_category_product END as cost_category_product,
	cost_category_product_domain,
	cost_category_environment,
	infrastructure_category,
	pricing_type,
	line_item_product_code,
	resource_tags_user_service,
	line_item_usage_type,
	pricing_unit,
	total_unblended_cost,
	total_public_cost,
	total_amortized_cost,
	COALESCE((
		SELECT SUM(service_count) FROM compiled_resources_counter WHERE 
			compiled_resources_counter.cost_category_product_domain=final_presentation.cost_category_product_domain AND 
			compiled_resources_counter.cost_category_organization=final_presentation.cost_category_organization AND 
			compiled_resources_counter.cost_category_vertical=final_presentation.cost_category_vertical AND 
			compiled_resources_counter.cost_category_product=final_presentation.cost_category_product AND 
			compiled_resources_counter.cost_category_environment=final_presentation.cost_category_environment AND 
			compiled_resources_counter.infrastructure_category=final_presentation.infrastructure_category AND 
			compiled_resources_counter.pricing_type=final_presentation.pricing_type AND 
			compiled_resources_counter.line_item_product_code=final_presentation.line_item_product_code AND 
			compiled_resources_counter.resource_tags_user_service=final_presentation.resource_tags_user_service AND 
			compiled_resources_counter.line_item_usage_type=final_presentation.line_item_usage_type AND 
			compiled_resources_counter.pricing_unit=final_presentation.pricing_unit
	), 0) AS resource_count,
	COALESCE((
		SELECT SUM(line_item_usage_amount) FROM compiled_resources_counter WHERE 
			compiled_resources_counter.cost_category_product_domain=final_presentation.cost_category_product_domain AND 
			compiled_resources_counter.cost_category_organization=final_presentation.cost_category_organization AND 
			compiled_resources_counter.cost_category_vertical=final_presentation.cost_category_vertical AND 
			compiled_resources_counter.cost_category_product=final_presentation.cost_category_product AND 
			compiled_resources_counter.cost_category_environment=final_presentation.cost_category_environment AND 
			compiled_resources_counter.infrastructure_category=final_presentation.infrastructure_category AND 
			compiled_resources_counter.pricing_type=final_presentation.pricing_type AND 
			compiled_resources_counter.line_item_product_code=final_presentation.line_item_product_code AND 
			compiled_resources_counter.resource_tags_user_service=final_presentation.resource_tags_user_service AND 
			compiled_resources_counter.line_item_usage_type=final_presentation.line_item_usage_type AND 
			compiled_resources_counter.pricing_unit=final_presentation.pricing_unit
	), 0) AS line_item_usage_amount
FROM final_presentation
