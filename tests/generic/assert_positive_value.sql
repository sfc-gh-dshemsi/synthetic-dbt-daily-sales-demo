-- Custom generic test: fails on any row where the column is zero or negative.
-- Use it in YAML like a built-in test:  data_tests: [assert_positive_value]
{% test assert_positive_value(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} <= 0

{% endtest %}
