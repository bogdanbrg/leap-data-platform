with line_items as (

    select
        order_key,
        count(*)        as line_item_count,
        sum(quantity)   as total_quantity,
        sum(net_amount) as net_amount
    from {{ ref('stg_line_items') }}
    group by order_key

)

select
    o.order_key,
    o.customer_key,
    o.order_date,
    o.order_status,
    o.order_priority,
    o.total_price,
    l.line_item_count,
    l.total_quantity,
    l.net_amount
from {{ ref('stg_orders') }} as o
left join line_items as l
    on o.order_key = l.order_key
