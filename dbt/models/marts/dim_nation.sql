select
    n.nation_key,
    n.nation_name,
    r.region_name
from {{ ref('stg_nations') }} as n
inner join {{ ref('stg_regions') }} as r
    on n.region_key = r.region_key
