-- Route custom schemas per environment.
--   prod: models land in the layer schema as named (STAGING, MARTS, HISTORY)
--   any other target: prefix with the target schema (DEV_STAGING, DEV_MARTS, ...)
-- Models without a custom schema use the target schema (DEV or PROD).
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim | upper }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
