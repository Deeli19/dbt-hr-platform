-- Grain: 1 row per employee, capturing the current state of the employee's attributes. This snapshot will be used as the source for our employee workforce fact table, allowing us to capture historical changes to employee attributes over time.
{% snapshot employee_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='employee_id',

        strategy='check',

        check_cols=[
            'employee_status',
            'title',
            'division',
            'department_type',
            'supervisor'
        ]
    )
}}

select *

from {{ ref('int_employee_identity') }}

{% endsnapshot %}