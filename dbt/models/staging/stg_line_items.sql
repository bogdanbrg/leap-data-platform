select
    l_orderkey                         as order_key,
    l_linenumber                       as line_number,
    l_quantity                         as quantity,
    l_extendedprice                    as extended_price,
    l_discount                         as discount,
    l_extendedprice * (1 - l_discount) as net_amount
from {{ source('tpch', 'lineitem') }}
