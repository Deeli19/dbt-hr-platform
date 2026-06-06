{% macro warn_deprecated_model(old_model, new_model) %}

    {% do exceptions.warn(
        "Model '" ~ old_model ~ "' is deprecated. "
        ~ "Please migrate downstream dependencies to '"
        ~ new_model ~ "'."
    ) %}

{% endmacro %}