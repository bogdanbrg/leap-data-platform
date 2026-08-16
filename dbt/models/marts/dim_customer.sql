select
    customer_key,
    customer_name,
    market_segment,
    account_balance,
    nation_key
from {{ ref('stg_customers') }}
