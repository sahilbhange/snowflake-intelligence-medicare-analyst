-- Keep explicit context so this file runs predictably from make targets.
use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema ANALYTICS;

create or replace semantic view DMEPOS_SEMANTIC_MODEL
	tables (
		MEDICARE_POS_DB.ANALYTICS.DIM_PROVIDER primary key (PROVIDER_NPI),
		FACT_CLAIMS as MEDICARE_POS_DB.ANALYTICS.FACT_DMEPOS_CLAIMS primary key (REFERRING_NPI,HCPCS_CODE)
	)
	relationships (
		FACT_TO_PROVIDER as FACT_CLAIMS(REFERRING_NPI) references DIM_PROVIDER(PROVIDER_NPI)
	)
	facts (
		FACT_CLAIMS.AVG_SUPPLIER_MEDICARE_ALLOWED as fact_claims.avg_supplier_medicare_allowed comment='Avg Medicare allowed (row-level)',
		FACT_CLAIMS.AVG_SUPPLIER_MEDICARE_PAYMENT as fact_claims.avg_supplier_medicare_payment comment='Avg Medicare payment (row-level)',
		FACT_CLAIMS.AVG_SUPPLIER_MEDICARE_STANDARD as fact_claims.avg_supplier_medicare_standard comment='Avg Medicare standard (row-level)',
		FACT_CLAIMS.AVG_SUPPLIER_SUBMITTED_CHARGE as fact_claims.avg_supplier_submitted_charge comment='Avg submitted charge (row-level)',
		FACT_CLAIMS.TOTAL_SUPPLIER_BENES as fact_claims.total_supplier_benes comment='Total beneficiaries (row-level)',
		FACT_CLAIMS.TOTAL_SUPPLIER_CLAIMS as fact_claims.total_supplier_claims comment='Total claims (row-level)',
		FACT_CLAIMS.TOTAL_SUPPLIER_SERVICES as fact_claims.total_supplier_services comment='Total services (row-level)',
		FACT_CLAIMS.TOTAL_SUPPLIERS as fact_claims.total_suppliers comment='Total suppliers (row-level)'
	)
	dimensions (
		DIM_PROVIDER.PROVIDER_CITY as dim_provider.provider_city comment='Provider city',
		DIM_PROVIDER.PROVIDER_COUNTRY as dim_provider.provider_country comment='Provider country',
		DIM_PROVIDER.PROVIDER_FIRST_NAME as dim_provider.provider_first_name comment='Provider first name',
		DIM_PROVIDER.PROVIDER_LAST_NAME as dim_provider.provider_last_name comment='Provider last name',
		DIM_PROVIDER.PROVIDER_NAME as concat_ws(' ', dim_provider.provider_first_name, dim_provider.provider_last_name) comment='Provider full name',
		DIM_PROVIDER.PROVIDER_NPI as dim_provider.referring_npi with synonyms=('npi','supplier_npi') comment='Provider NPI',
		DIM_PROVIDER.PROVIDER_SPECIALTY_CODE as dim_provider.provider_specialty_code comment='Specialty code',
		DIM_PROVIDER.PROVIDER_SPECIALTY_DESC as dim_provider.provider_specialty_desc with synonyms=('medical specialty','provider specialty','specialty') comment='Specialty description',
		DIM_PROVIDER.PROVIDER_STATE as dim_provider.provider_state with synonyms=('location','provider location','state') comment='Provider state',
		DIM_PROVIDER.PROVIDER_ZIP as dim_provider.provider_zip comment='Provider ZIP',
		FACT_CLAIMS.HCPCS_CODE as fact_claims.hcpcs_code with synonyms=('billing code','code','hcpcs','procedure code') comment='HCPCS code',
		FACT_CLAIMS.HCPCS_DESCRIPTION as fact_claims.hcpcs_description with synonyms=('code description','procedure description') comment='HCPCS description',
		FACT_CLAIMS.RBCS_ID as fact_claims.rbcs_id comment='RBCS category id',
		FACT_CLAIMS.REFERRING_NPI as fact_claims.referring_npi with synonyms=('npi','supplier_npi') comment='Referring provider NPI',
		FACT_CLAIMS.SUPPLIER_RENTAL_INDICATOR as fact_claims.supplier_rental_indicator with synonyms=('is rental','rental flag','rental indicator') comment='Rental indicator'
	)
	metrics (
		FACT_CLAIMS.ALLOWED_PER_CLAIM as sum(fact_claims.avg_supplier_medicare_allowed) / nullif(sum(fact_claims.total_supplier_claims), 0) comment='Allowed amount per claim',
		FACT_CLAIMS.ALLOWED_PER_SERVICE as sum(fact_claims.avg_supplier_medicare_allowed) / nullif(sum(fact_claims.total_supplier_services), 0) comment='Allowed amount per service',
		FACT_CLAIMS.AVG_MEDICARE_ALLOWED as avg(fact_claims.avg_supplier_medicare_allowed) comment='Average Medicare allowed',
		FACT_CLAIMS.AVG_MEDICARE_PAYMENT as avg(fact_claims.avg_supplier_medicare_payment) comment='Average Medicare payment',
		FACT_CLAIMS.AVG_MEDICARE_STANDARD as avg(fact_claims.avg_supplier_medicare_standard) comment='Average Medicare standard',
		FACT_CLAIMS.AVG_SUBMITTED_CHARGE as avg(fact_claims.avg_supplier_submitted_charge) comment='Average submitted charge',
		FACT_CLAIMS.BENEFICIARIES_PER_CLAIM as sum(fact_claims.total_supplier_benes) / nullif(sum(fact_claims.total_supplier_claims), 0) comment='Beneficiaries per claim',
		FACT_CLAIMS.CHARGE_TO_ALLOWED_RATIO as avg(fact_claims.avg_supplier_submitted_charge) / nullif(avg(fact_claims.avg_supplier_medicare_allowed), 0) comment='Charge-to-allowed ratio',
		FACT_CLAIMS.CLAIMS_PER_SUPPLIER as sum(fact_claims.total_supplier_claims) / nullif(sum(fact_claims.total_suppliers), 0) comment='Claims per supplier',
		FACT_CLAIMS.PAYMENT_TO_ALLOWED_RATIO as avg(fact_claims.avg_supplier_medicare_payment) / nullif(avg(fact_claims.avg_supplier_medicare_allowed), 0) comment='Payment-to-allowed ratio',
		FACT_CLAIMS.SERVICES_PER_CLAIM as sum(fact_claims.total_supplier_services) / nullif(sum(fact_claims.total_supplier_claims), 0) comment='Services per claim',
		FACT_CLAIMS.TOTAL_BENEFICIARIES_SUM as sum(fact_claims.total_supplier_benes) with synonyms=('beneficiary count','number of beneficiaries','patient count','total beneficiaries') comment='Total beneficiaries',
		FACT_CLAIMS.TOTAL_CLAIMS_SUM as sum(fact_claims.total_supplier_claims) with synonyms=('claim count','claims volume','number of claims','total claims') comment='Total claims',
		FACT_CLAIMS.TOTAL_SERVICES_SUM as sum(fact_claims.total_supplier_services) with synonyms=('number of services','service count','services volume','total services') comment='Total services',
		FACT_CLAIMS.TOTAL_SUPPLIERS_SUM as sum(fact_claims.total_suppliers) with synonyms=('number of suppliers','provider count','supplier count','total suppliers') comment='Total suppliers'
	)
	comment='Medicare DMEPOS Claims Semantic Model (v1.2.0)

Analyzes Medicare Durable Medical Equipment, Prosthetics, Orthotics, and Supplies (DMEPOS)
claims data at the provider + HCPCS code grain.
'
	ai_sql_generation 'Use only model-defined objects and fields from FACT_CLAIMS and DIM_PROVIDER. Do not invent table names, columns, joins, or metrics.
Prefer model metrics when a matching metric exists instead of rebuilding expressions ad hoc.
For top/highest/ranking questions, always include ORDER BY + LIMIT. If user does not specify N, default to LIMIT 10.
For ranked outputs, make ordering deterministic with a stable tie-breaker (for example: ORDER BY metric DESC, dimension ASC).
Use named filters (rentals_only, common_hcpcs, durable_medical_equipment, high_volume_providers, california_providers, texas_providers, top_states) when relevant.
Always round monetary amounts to 2 decimals in final projections.
For ratio math, use NULLIF in denominators to avoid divide-by-zero behavior.
If the request is ambiguous (missing entity/filter/grain), ask one clarification question instead of guessing.
'
	ai_question_categorization 'Accept questions about DMEPOS claims, providers, HCPCS codes, Medicare payments, and geography.
Reject questions requesting patient-level or identifiable data.
For device definitions or code lookups, suggest Cortex Search sources.
This data is a single time-period snapshot. Time-based trending or year-over-year questions are not supported; inform the user if asked.
'
	with extension (
			CA='{
  "tables": [
    {
      "name": "DIM_PROVIDER",
      "dimensions": [
        {
          "name": "PROVIDER_CITY"
        },
        {
          "name": "PROVIDER_COUNTRY"
        },
        {
          "name": "PROVIDER_FIRST_NAME"
        },
        {
          "name": "PROVIDER_LAST_NAME"
        },
        {
          "name": "PROVIDER_NAME"
        },
        {
          "name": "PROVIDER_NPI"
        },
        {
          "name": "PROVIDER_SPECIALTY_CODE"
        },
        {
          "name": "PROVIDER_SPECIALTY_DESC",
          "sample_values": [
            "Family Practice",
            "Internal Medicine",
            "Nurse Practitioner",
            "Orthopedic Surgery",
            "Endocrinology"
          ]
        },
        {
          "name": "PROVIDER_STATE",
          "sample_values": [
            "TX",
            "CA",
            "NY",
            "FL",
            "PA"
          ]
        },
        {
          "name": "PROVIDER_ZIP"
        }
      ]
    },
    {
      "name": "FACT_CLAIMS",
      "dimensions": [
        {
          "name": "HCPCS_CODE",
          "sample_values": [
            "A4239",
            "E1390",
            "A4253",
            "E1392",
            "E0601"
          ]
        },
        {
          "name": "HCPCS_DESCRIPTION"
        },
        {
          "name": "RBCS_ID"
        },
        {
          "name": "REFERRING_NPI"
        },
        {
          "name": "SUPPLIER_RENTAL_INDICATOR",
          "sample_values": [
            "Y",
            "N"
          ]
        }
      ],
      "facts": [
        {
          "name": "AVG_SUPPLIER_MEDICARE_ALLOWED"
        },
        {
          "name": "AVG_SUPPLIER_MEDICARE_PAYMENT"
        },
        {
          "name": "AVG_SUPPLIER_MEDICARE_STANDARD"
        },
        {
          "name": "AVG_SUPPLIER_SUBMITTED_CHARGE"
        },
        {
          "name": "TOTAL_SUPPLIER_BENES"
        },
        {
          "name": "TOTAL_SUPPLIER_CLAIMS"
        },
        {
          "name": "TOTAL_SUPPLIER_SERVICES"
        },
        {
          "name": "TOTAL_SUPPLIERS"
        }
      ],
      "metrics": [
        {
          "name": "ALLOWED_PER_CLAIM"
        },
        {
          "name": "ALLOWED_PER_SERVICE"
        },
        {
          "name": "AVG_MEDICARE_ALLOWED"
        },
        {
          "name": "AVG_MEDICARE_PAYMENT"
        },
        {
          "name": "AVG_MEDICARE_STANDARD"
        },
        {
          "name": "AVG_SUBMITTED_CHARGE"
        },
        {
          "name": "BENEFICIARIES_PER_CLAIM"
        },
        {
          "name": "CHARGE_TO_ALLOWED_RATIO"
        },
        {
          "name": "CLAIMS_PER_SUPPLIER"
        },
        {
          "name": "PAYMENT_TO_ALLOWED_RATIO"
        },
        {
          "name": "SERVICES_PER_CLAIM"
        },
        {
          "name": "TOTAL_BENEFICIARIES_SUM"
        },
        {
          "name": "TOTAL_CLAIMS_SUM"
        },
        {
          "name": "TOTAL_SERVICES_SUM"
        },
        {
          "name": "TOTAL_SUPPLIERS_SUM"
        }
      ],
      "filters": [
        {
          "name": "california_providers",
          "description": "Providers located in California",
          "expr": "provider_state = ''CA''"
        },
        {
          "name": "common_hcpcs",
          "description": "Focus on commonly occurring HCPCS codes",
          "expr": "hcpcs_code in (''A4239'',''E1390'',''E0431'',''E1392'',''E0601'')"
        },
        {
          "name": "durable_medical_equipment",
          "description": "DME codes (E-codes for equipment)",
          "expr": "hcpcs_code like ''E%''"
        },
        {
          "name": "exclude_null_hcpcs",
          "description": "Exclude null HCPCS codes",
          "expr": "hcpcs_code is not null"
        },
        {
          "name": "high_volume_providers",
          "description": "Providers with more than 100 total claims",
          "expr": "total_supplier_claims > 100"
        },
        {
          "name": "rentals_only",
          "description": "Rentals only",
          "expr": "supplier_rental_indicator = ''Y''"
        },
        {
          "name": "texas_providers",
          "description": "Providers located in Texas",
          "expr": "provider_state = ''TX''"
        },
        {
          "name": "top_states",
          "description": "Focus on states with highest claim volume (TX, CA, NY, FL, PA)",
          "expr": "provider_state in (''TX'', ''CA'', ''NY'', ''FL'', ''PA'')"
        }
      ]
    }
  ],
  "relationships": [
    {
      "name": "FACT_TO_PROVIDER"
    }
  ],
  "verified_queries": [
    {
      "name": "AVG_MEDICARE_PAYMENT_BY_SPECIALTY",
      "sql": "select dp.provider_specialty_desc, avg(fc.avg_supplier_medicare_payment) as avg_medicare_payment from fact_claims fc left join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_specialty_desc is not null group by dp.provider_specialty_desc order by avg_medicare_payment desc nulls last",
      "question": "What is the average Medicare payment amount by provider specialty?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "TOP_HCPCS_BY_CLAIMS",
      "sql": "select hcpcs_code, sum(total_supplier_claims) as claims from fact_claims group by hcpcs_code order by claims desc, hcpcs_code asc limit 5",
      "question": "What are the top 5 HCPCS codes by total supplier claims?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "PAYMENT_RATIO_BY_STATE",
      "sql": "select dp.provider_state, round(avg(fc.avg_supplier_medicare_payment) / nullif(avg(fc.avg_supplier_medicare_allowed), 0), 2) as payment_ratio from fact_claims fc join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_state is not null group by dp.provider_state order by payment_ratio desc, dp.provider_state asc limit 10",
      "question": "Which states have the best payment to allowed ratio?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "CALIFORNIA_HIGH_VOLUME_PROVIDERS",
      "sql": "select dp.provider_name, dp.provider_specialty_desc, sum(fc.total_supplier_claims) as total_claims from fact_claims fc join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_state = ''CA'' and fc.total_supplier_claims > 100 group by dp.provider_name, dp.provider_specialty_desc order by total_claims desc, dp.provider_name asc limit 10",
      "question": "Show me high volume providers in California with their claim counts",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "DME_CODES_SUMMARY",
      "sql": "select count(distinct hcpcs_code) as unique_codes, sum(total_supplier_claims) as total_claims, sum(total_supplier_services) as total_services, round(avg(avg_supplier_medicare_payment), 2) as avg_payment from fact_claims where hcpcs_code like ''E%''",
      "question": "What is the summary of DME equipment codes (E-codes)?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "SPECIALTY_EFFICIENCY_METRICS",
      "sql": "select dp.provider_specialty_desc, count(distinct dp.provider_npi) as provider_count, sum(fc.total_supplier_claims) as total_claims, round(sum(fc.total_supplier_claims) / nullif(count(distinct dp.provider_npi), 0), 2) as claims_per_provider, round(sum(fc.total_supplier_benes) / nullif(sum(fc.total_supplier_claims), 0), 2) as beneficiaries_per_claim from fact_claims fc join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_specialty_desc in (''Family Practice'', ''Internal Medicine'', ''Nurse Practitioner'', ''Orthopedic Surgery'', ''Endocrinology'') group by dp.provider_specialty_desc order by total_claims desc, dp.provider_specialty_desc asc",
      "question": "Show me efficiency metrics by specialty for top specialties",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "TOP_STATES_BY_AVG_ALLOWED",
      "sql": "select dp.provider_state, avg(fc.avg_supplier_medicare_allowed) as avg_allowed from fact_claims fc left join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_state is not null group by dp.provider_state order by avg_allowed desc, dp.provider_state asc limit 5",
      "question": "Which states have the highest average Medicare allowed amount?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "TOP_SPECIALTIES_BY_COUNT",
      "sql": "select dp.provider_specialty_desc, count(*) as providers from dim_provider dp group by dp.provider_specialty_desc order by providers desc, dp.provider_specialty_desc asc limit 5",
      "question": "Which provider specialties appear most often in the claims?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "HCPCS_E1390_SUMMARY",
      "sql": "select sum(total_supplier_claims) as claims, sum(total_supplier_services) as services from fact_claims where hcpcs_code = ''E1390''",
      "question": "Show total claims and services for HCPCS E1390.",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "HCPCS_E0431_SUMMARY",
      "sql": "select sum(total_suppliers) as suppliers, sum(total_supplier_claims) as claims from fact_claims where hcpcs_code = ''E0431''",
      "question": "What are the total suppliers and claims for HCPCS E0431?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "RENTALS_ONLY_SERVICES",
      "sql": "select sum(total_supplier_services) as rental_services from fact_claims where supplier_rental_indicator = ''Y''",
      "question": "What is the total supplier services for rentals only?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "TOP_HCPCS_BY_BENEFICIARIES",
      "sql": "select hcpcs_code, sum(total_supplier_benes) as beneficiaries from fact_claims group by hcpcs_code order by beneficiaries desc, hcpcs_code asc limit 5",
      "question": "Which HCPCS codes have the highest total beneficiaries?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "TOP_ZIP_BY_SUPPLIERS",
      "sql": "select dp.provider_zip, sum(fc.total_suppliers) as suppliers from fact_claims fc left join dim_provider dp on fc.referring_npi = dp.provider_npi where dp.provider_zip is not null group by dp.provider_zip order by suppliers desc, dp.provider_zip asc limit 3",
      "question": "What are the top 3 ZIP codes by total suppliers?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    },
    {
      "name": "RENTALS_VS_NONRENTALS",
      "sql": "select supplier_rental_indicator, sum(total_supplier_claims) as claims, sum(total_supplier_services) as services from fact_claims group by supplier_rental_indicator order by supplier_rental_indicator asc",
      "question": "How do rentals compare to non-rentals in total claims and services?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": true
    },
    {
      "name": "TOP_HCPCS_BY_PAYMENT_TO_ALLOWED_RATIO",
      "sql": "select hcpcs_code, avg(avg_supplier_medicare_payment) / nullif(avg(avg_supplier_medicare_allowed),0) as payment_to_allowed_ratio from fact_claims group by hcpcs_code order by payment_to_allowed_ratio desc, hcpcs_code asc limit 5",
      "question": "Which HCPCS codes have the highest payment-to-allowed ratio?",
      "verified_by": "Sahil Bhange",
      "use_as_onboarding_question": false
    }
  ]
}'
		);
