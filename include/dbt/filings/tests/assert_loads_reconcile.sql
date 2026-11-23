-- No quarter may have lost more than 0.05% of its rows on the way in.
select source_quarter, table_name, file_rows, loaded_rows
from {{ source('raw', 'load_log') }}
where abs(rejected_rows) > file_rows * 0.0005