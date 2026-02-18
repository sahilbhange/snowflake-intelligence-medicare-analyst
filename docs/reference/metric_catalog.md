# Metric Catalog

Use this catalog when defining, validating, or explaining semantic-model metrics.

## Volume Metrics

### TOTAL_CLAIMS_SUM
| Attribute | Value |
|-----------|-------|
| **Definition** | Total count of supplier claims submitted for provider-HCPCS combinations |
| **Calculation** | `SUM(total_supplier_claims)` |
| **Data Type** | Integer |
| **Synonyms** | claim count, claims volume, number of claims, total claims |

**Use Cases:**
- Provider productivity analysis
- Service utilization trending
- HCPCS code volume ranking

**Edge Cases:**
- Zero claims possible for inactive providers in dimension
- High values may indicate billing patterns worth reviewing
- Aggregated at provider+HCPCS level, not individual claims

### TOTAL_SERVICES_SUM
| Attribute | Value |
|-----------|-------|
| **Definition** | Total count of services rendered across all claims |
| **Calculation** | `SUM(total_supplier_services)` |
| **Data Type** | Integer |
| **Synonyms** | service count, services volume, number of services, total services |

**Use Cases:**
- Service intensity analysis
- Comparison across HCPCS codes
- Efficiency metrics denominator

**Edge Cases:**
- Services >= Claims (one claim may have multiple services)
- Null handling: treat as 0 for aggregations

### TOTAL_BENEFICIARIES_SUM
| Attribute | Value |
|-----------|-------|
| **Definition** | Total count of distinct Medicare beneficiaries served |
| **Calculation** | `SUM(total_supplier_benes)` |
| **Data Type** | Integer |
| **Synonyms** | beneficiary count, patient count, number of beneficiaries, total beneficiaries |

**Use Cases:**
- Patient reach analysis
- Market penetration by provider or region
- Public health impact assessment

**Edge Cases:**
- Same beneficiary counted once per provider-HCPCS combination
- Not deduplicated across providers (same patient may appear multiple times)
- Suppressed for very small counts in source data

### TOTAL_SUPPLIERS_SUM
| Attribute | Value |
|-----------|-------|
| **Definition** | Total count of unique suppliers involved |
| **Calculation** | `SUM(total_suppliers)` |
| **Data Type** | Integer |
| **Synonyms** | supplier count, provider count, number of suppliers |

**Use Cases:**
- Market concentration analysis
- Supplier network size

**Edge Cases:**
- Represents suppliers, not referring providers
- May differ from provider count due to aggregation

## Payment Metrics

### AVG_MEDICARE_PAYMENT
| Attribute | Value |
|-----------|-------|
| **Definition** | Average Medicare payment amount per service |
| **Calculation** | `AVG(avg_supplier_medicare_payment)` |
| **Data Type** | Decimal (4 decimal places) |
| **Currency** | USD |

**Use Cases:**
- Reimbursement analysis
- Cost benchmarking across regions/specialties
- Payment variance detection

**Edge Cases:**
- Excludes patient cost-sharing (deductibles, coinsurance)
- May include adjustments and denials in average
- Round to 2 decimals for display

### AVG_MEDICARE_ALLOWED
| Attribute | Value |
|-----------|-------|
| **Definition** | Average Medicare allowed amount (approved for payment) |
| **Calculation** | `AVG(avg_supplier_medicare_allowed)` |
| **Data Type** | Decimal (4 decimal places) |
| **Currency** | USD |

**Use Cases:**
- Fee schedule analysis
- Payment vs. allowed comparison
- Regional pricing variation

**Edge Cases:**
- Allowed >= Payment (payment may be reduced)
- Includes all approved amounts before patient responsibility

### AVG_SUBMITTED_CHARGE
| Attribute | Value |
|-----------|-------|
| **Definition** | Average amount billed by suppliers before Medicare processing |
| **Calculation** | `AVG(avg_supplier_submitted_charge)` |
| **Data Type** | Decimal (4 decimal places) |
| **Currency** | USD |

**Use Cases:**
- Billing pattern analysis
- Charge vs. allowed variance
- Market pricing insights

**Edge Cases:**
- Typically higher than allowed/payment
- Reflects supplier pricing, not Medicare rates

## Derived Metrics

### PAYMENT_TO_ALLOWED_RATIO
| Attribute | Value |
|-----------|-------|
| **Definition** | Ratio of Medicare payment to allowed amount |
| **Calculation** | `AVG(avg_supplier_medicare_payment) / NULLIF(AVG(avg_supplier_medicare_allowed), 0)` |
| **Data Type** | Decimal |
| **Expected Range** | 0.0 to 1.0 (typically 0.7-0.9) |

**Use Cases:**
- Payment efficiency analysis
- Identify states/providers with highest reimbursement rates
- Detect anomalies (ratio > 1.0 is unusual)

**Edge Cases:**
- Null if allowed = 0 (NULLIF protection)
- Values > 1.0 may indicate data quality issues

### SERVICES_PER_CLAIM
| Attribute | Value |
|-----------|-------|
| **Definition** | Average number of services per claim |
| **Calculation** | `SUM(total_supplier_services) / NULLIF(SUM(total_supplier_claims), 0)` |
| **Data Type** | Decimal |
| **Expected Range** | >= 1.0 |

**Use Cases:**
- Claim complexity analysis
- Efficiency comparison across specialties

### CLAIMS_PER_SUPPLIER
| Attribute | Value |
|-----------|-------|
| **Definition** | Average claims per supplier |
| **Calculation** | `SUM(total_supplier_claims) / NULLIF(SUM(total_suppliers), 0)` |
| **Data Type** | Decimal |

**Use Cases:**
- Supplier productivity
- Market concentration

### BENEFICIARIES_PER_CLAIM
| Attribute | Value |
|-----------|-------|
| **Definition** | Average beneficiaries per claim |
| **Calculation** | `SUM(total_supplier_benes) / NULLIF(SUM(total_supplier_claims), 0)` |
| **Data Type** | Decimal |
| **Expected Range** | Typically <= 1.0 |

**Use Cases:**
- Patient coverage analysis
- Billing pattern detection

### ALLOWED_PER_CLAIM
| Attribute | Value |
|-----------|-------|
| **Definition** | Allowed amount per claim |
| **Calculation** | `SUM(avg_supplier_medicare_allowed) / NULLIF(SUM(total_supplier_claims), 0)` |
| **Data Type** | Decimal |

### ALLOWED_PER_SERVICE
| Attribute | Value |
|-----------|-------|
| **Definition** | Allowed amount per service |
| **Calculation** | `SUM(avg_supplier_medicare_allowed) / NULLIF(SUM(total_supplier_services), 0)` |
| **Data Type** | Decimal |

## Filter Reference

| Filter Name | Description | Expression |
|-------------|-------------|------------|
| `california_providers` | Providers in CA | `provider_state = 'CA'` |
| `texas_providers` | Providers in TX | `provider_state = 'TX'` |
| `top_states` | High-volume states | `provider_state IN ('TX','CA','NY','FL','PA')` |
| `durable_medical_equipment` | E-codes (equipment) | `hcpcs_code LIKE 'E%'` |
| `common_hcpcs` | Frequently used codes | `hcpcs_code IN ('A4239','E1390','E0431','E1392','E0601')` |
| `exclude_null_hcpcs` | Exclude nulls | `hcpcs_code IS NOT NULL` |
| `rentals_only` | Rental equipment | `supplier_rental_indicator = 'Y'` |
| `high_volume_providers` | > 100 claims | `total_supplier_claims > 100` |

## Data Caveats

1. **Aggregation Level**: Data is at provider + HCPCS grain, not individual claim level
2. **Temporal Scope**: Single snapshot; no year-over-year trends available
3. **Rental Indicator**: At HCPCS level, not claim level
4. **Payment Amounts**: Medicare portion only; excludes patient responsibility
5. **Beneficiary Counts**: Not deduplicated across providers
6. **Suppression**: Small cell sizes may be suppressed in source data

## Related Documentation

- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md)
- [Data Dictionary](../governance/data_dictionary.md)
