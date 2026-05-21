{% for attribute in attributes %}

    lag({{ attribute }}) over (
        partition by employee_id
        order by dbt_valid_from
    ) as previous_{{ attribute }}

    {% if not loop.last %},{% endif %}

{% endfor %}