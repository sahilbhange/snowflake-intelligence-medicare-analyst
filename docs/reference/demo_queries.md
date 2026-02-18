# Demo Queries

Use this list to quickly validate routing and answer quality before demos or recordings.

## Core Query Matrix

| ID | Question | Expected Route | Expected Pattern |
|---|---|---|---|
| Q1 | What is HCPCS code E1390? | Search (`HCPCS_SEARCH_SVC`) | Definition lookup by code |
| Q2 | Find oxygen concentrator devices | Search (`DEVICE_SEARCH_SVC`) | Semantic text search on device catalog |
| Q3 | Top 5 states by total Medicare claims | Analyst | `GROUP BY provider_state ORDER BY SUM(total_supplier_claims) DESC LIMIT 5` |
| Q4 | Average Medicare payment for E1390 | Analyst | `WHERE hcpcs_code='E1390'` + `AVG(avg_supplier_medicare_payment)` |
| Q5 | Compare rental vs purchase by total claims | Analyst | `GROUP BY supplier_rental_indicator` |
| Q6 | What are oxygen concentrators and how much does Medicare spend on them? | Hybrid (Search -> Analyst) | Lookup related codes, then `SUM` payments by code set |
| Q7 | Find wheelchair devices, then top 5 states by wheelchair claims | Hybrid (Search -> Analyst) | Extract wheelchair codes, then state ranking |
| Q8 | Which providers in California have highest diabetes-supply volume? | Analyst | CA filter + domain code/category filter + provider ranking |
| Q9 | Which specialty has most providers and what is average payment? | Analyst | Group by specialty + provider count + avg payment |
| Q10 | Top 5 most expensive HCPCS by average submitted charge | Analyst | `ORDER BY AVG(avg_supplier_submitted_charge) DESC LIMIT 5` |

## Routing Guardrail Checks

| ID | Question | Expected Route | Expected Pattern |
|---|---|---|---|
| G1 | What does DMEPOS stand for? | Search or fallback definition | Acronym definition response |
| G2 | Show me all the data | Clarification | Agent asks for scope (provider, HCPCS, geography, payments) |
| G3 | Year-over-year growth in claims | Analyst + limitation handling | Explain no time-series dimension in current dataset |
| G4 | Which oxygen concentrator brand is most reliable? | Guardrail response | Explain reliability is out of scope of claims dataset |

## Quick Readiness Checklist

- [ ] Search services return results (HCPCS, device, provider).
- [ ] Analyst returns results for Q3-Q5.
- [ ] Hybrid flow works for Q6-Q7.
- [ ] Guardrails are enforced for G2-G4.
- [ ] Data exists in `ANALYTICS.FACT_DMEPOS_CLAIMS`.
