with dates as (

    select
        dateadd(day, seq4(), '2020-01-01') as calendar_date
    from table(generator(rowcount => 3650))

),

final as (

    select

        -- surrogate-style date key
        to_number(to_char(calendar_date, 'YYYYMMDD')) as date_key,

        -- base date
        calendar_date,

        -- calendar breakdown
        year(calendar_date) as year_number,
        quarter(calendar_date) as quarter_number,
        month(calendar_date) as month_number,
        monthname(calendar_date) as month_name,

        week(calendar_date) as week_number,
        day(calendar_date) as day_number,

        dayname(calendar_date) as day_name,
        dayofweek(calendar_date) as day_of_week_number,

        -- flags
        case
            when dayofweek(calendar_date) in (0, 6)
            then true
            else false
        end as is_weekend,

        case
            when last_day(calendar_date) = calendar_date
            then true
            else false
        end as is_month_end,

        case
            when calendar_date = date_trunc('month', calendar_date)
            then true
            else false
        end as is_month_start

    from dates

)

select * from final