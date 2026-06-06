{% macro is_archive_day(day_of_month=1) %}
    {{ return(run_started_at.day == day_of_month) }}
{% endmacro %}