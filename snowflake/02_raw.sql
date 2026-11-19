USE ROLE FIN_PIPELINE;
USE WAREHOUSE FIN_WH;
USE SCHEMA FIN.RAW;

-- How to read the SEC's files: tab-separated, quoted only when needed, no escape character
CREATE OR REPLACE FILE FORMAT SEC_TSV
  TYPE = CSV FIELD_DELIMITER = '\t' SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"' ESCAPE_UNENCLOSED_FIELD = NONE
  EMPTY_FIELD_AS_NULL = TRUE ENCODING = 'UTF8';

-- One row per filing
CREATE TABLE IF NOT EXISTS SUB_RAW (
    adsh STRING, cik STRING, name STRING, sic STRING, countryba STRING, form STRING,
    period STRING, fy STRING, fp STRING, filed STRING, accepted STRING,
    source_quarter STRING, file_row NUMBER, loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- One row per reported number
CREATE TABLE IF NOT EXISTS NUM_RAW (
    adsh STRING, tag STRING, version STRING, ddate STRING, qtrs STRING, uom STRING,
    segments STRING, coreg STRING, value STRING, footnote STRING,
    source_quarter STRING, file_row NUMBER, loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- The loader's own record of what it did
CREATE TABLE IF NOT EXISTS LOAD_LOG (
    source_quarter STRING, table_name STRING, file_rows NUMBER, loaded_rows NUMBER, rejected_rows NUMBER,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SHOW TABLES IN SCHEMA FIN.RAW;