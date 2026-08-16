{#
  In production, models land directly in the schemas Terraform created:
  STAGING and MARTS. Everywhere else dbt's default prefixing applies, so a
  developer building locally writes to DBT_BOGDAN_staging and never touches
  a shared schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}

    {%- if target.name == 'prod' and custom_schema_name is not none -%}
        {{ custom_schema_name | trim | upper }}

    {%- elif custom_schema_name is none -%}
        {{ default_schema }}

    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}

    {%- endif -%}
{%- endmacro %}
