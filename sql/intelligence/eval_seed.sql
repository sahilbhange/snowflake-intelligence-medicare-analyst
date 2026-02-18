-- Seed golden eval prompts for Analyst regression checks.
-- Use after semantic model updates to spot routing/SQL drift.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema INTELLIGENCE;

insert into INTELLIGENCE.ANALYST_EVAL_SET (eval_id, category, question, expected_pattern, notes)
values
  ('Q01', 'provider', 'Top 5 providers by total supplier claims in MD', 'order by total_supplier_claims desc limit 5 where provider_state = ''MD''', null),
  ('Q02', 'provider', 'Providers in CA with highest avg Medicare allowed', 'order by avg_supplier_medicare_allowed desc where provider_state = ''CA''', null),
  ('Q03', 'hcpcs', 'Total suppliers and claims for HCPCS E0431', 'where hcpcs_code = ''E0431''', null),
  ('Q04', 'hcpcs', 'Average Medicare payment by HCPCS code', 'group by hcpcs_code', null),
  ('Q05', 'rbcs', 'Top RBCS categories by total supplier services', 'group by rbcs_id order by total_supplier_services desc', null),
  ('Q06', 'rbcs', 'Avg Medicare allowed by RBCS category DC002N', 'where rbcs_id = ''DC002N''', null),
  ('Q07', 'rental', 'Share of supplier rentals vs non-rentals', 'group by supplier_rental_indicator', null),
  ('Q08', 'geo', 'Total claims by provider state', 'group by provider_state', null),
  ('Q09', 'geo', 'Top 3 ZIP codes by total suppliers', 'group by provider_zip order by total_suppliers desc limit 3', null),
  ('Q10', 'general', 'Average Medicare allowed across all records', 'avg_supplier_medicare_allowed', null),
  ('Q11', 'general', 'Total supplier beneficiaries by HCPCS DC002N', 'where rbcs_id = ''DC002N''', null),
  ('Q12', 'general', 'Which HCPCS codes have highest avg submitted charge?', 'order by avg_supplier_submitted_charge desc', null),
  ('Q13', 'general', 'List provider specialties by count of claims', 'group by provider_specialty_desc', null),
  ('Q14', 'general', 'Total supplier services for rentals only', 'where supplier_rental_indicator = ''Y''', null),
  ('Q15', 'general', 'Total supplier claims per provider', 'group by referring_npi', null),
  ('Q16', 'hcpcs', 'Top 5 HCPCS codes by total supplier claims', 'group by hcpcs_code order by total_supplier_claims desc limit 5', 'Use overall claims to surface highest-volume codes.'),
  ('Q17', 'geo', 'Top 5 states by average Medicare allowed', 'group by provider_state order by avg_supplier_medicare_allowed desc limit 5', 'Highlights geographic variation in allowed amounts.'),
  ('Q18', 'provider', 'Top 5 specialties by provider count in claims', 'group by provider_specialty_desc order by count(*) desc limit 5', 'Counts rows grouped by specialty.'),
  ('Q19', 'hcpcs', 'Claims and services for HCPCS E1390', 'where hcpcs_code = ''E1390''', 'Checks a top-volume code from profiling.'),
  ('Q20', 'hcpcs', 'Top 5 HCPCS by total supplier beneficiaries', 'group by hcpcs_code order by total_supplier_benes desc limit 5', 'Uses beneficiary counts to rank codes.');
