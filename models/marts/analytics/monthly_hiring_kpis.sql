with recruitment as (

    select * from {{ ref('fct_recruitment_incremental') }}

),

dim_date as (

    select * from {{ ref('dim_date') }}

),

final as (

    select

        year_number as application_year,
        month_name as application_month,

        count(*) as total_applications,

        sum(hired_flag) as total_hires,

        round(
            sum(hired_flag) * 100.0 / count(*),
            2
        ) as hire_conversion_rate,

    from recruitment r
    left join dim_date d
        on r.application_date = d.calendar_date

    group by 1, 2

)

select * from final