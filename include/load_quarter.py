"""Load one quarter of the SEC Financial Statement Data Sets into FIN.RAW. Safe to run twice.

Usage inside the Airflow container:  python include/load_quarter.py 2025q1
"""
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path

import requests
import snowflake.connector

BASE_URL = "https://www.sec.gov/files/dera/data/financial-statement-data-sets"

# The data contract: the columns this pipeline needs from each file.
WANTED = {
    "sub": ["adsh", "cik", "name", "sic", "countryba", "form", "period", "fy", "fp", "filed", "accepted"],
    "num": ["adsh", "tag", "version", "ddate", "qtrs", "uom", "segments", "coreg", "value", "footnote"],
}
TABLE = {"sub": "SUB_RAW", "num": "NUM_RAW"}
MAX_REJECTED_SHARE = 0.0005     # refuse to commit if more than 0.05% of a file's rows fail to load


def connect():
    # The key is read here and passed as text: the file is shared from Windows, where the container sees it as
    # writable by everyone, and the connector refuses a key FILE with those permissions.
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        authenticator="SNOWFLAKE_JWT",
        private_key=Path(os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]).read_text(),
        role="FIN_PIPELINE", warehouse="FIN_WH", database="FIN", schema="RAW",
    )


def download(quarter: str, dest: Path) -> int:
    url = f"{BASE_URL}/{quarter}.zip"
    agent = os.environ["SEC_USER_AGENT"]
    if "PUT-YOUR" in agent or "@" not in agent:
        raise ValueError("Put your own name and email in the SEC_USER_AGENT line of .env, then run astro dev restart")
    headers = {"User-Agent": agent}     # the SEC returns 403 without this
    with requests.get(url, headers=headers, stream=True, timeout=300) as r:
        if r.status_code in (403, 404):
            raise FileNotFoundError(f"{url} returned {r.status_code}: not published yet, or SEC_USER_AGENT is missing")
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                f.write(chunk)
    return dest.stat().st_size


def extract(zip_path: Path, member: str, dest: Path):
    """Unzip one file. Returns its header columns and its number of data rows."""
    with zipfile.ZipFile(zip_path) as z, z.open(member) as src, open(dest, "wb") as out:
        header = src.readline()
        out.write(header)
        rows = 0
        for line in src:
            out.write(line)
            rows += 1
    return header.decode("utf-8").rstrip("\r\n").split("\t"), rows


def copy_table(cur, quarter: str, name: str, header: list, file_rows: int) -> dict:
    missing = [c for c in WANTED[name] if c not in header]
    if missing:
        raise RuntimeError(f"{quarter}/{name}.txt no longer has columns {missing}. The source layout changed.")

    # Pick columns by NAME from the header, so a reordered or widened file still loads correctly.
    select_list = ", ".join(f"t.${header.index(c) + 1}" for c in WANTED[name])
    table = TABLE[name]

    cur.execute(f"DELETE FROM {table} WHERE source_quarter = %s", (quarter,))
    cur.execute(f"""
        COPY INTO {table} ({", ".join(WANTED[name])}, source_quarter, file_row)
        FROM (SELECT {select_list}, '{quarter}', METADATA$FILE_ROW_NUMBER
              FROM @LANDING/{quarter}/{name}.txt.gz t)
        FILE_FORMAT = (FORMAT_NAME = 'SEC_TSV') ON_ERROR = CONTINUE FORCE = TRUE
    """)
    cur.execute(f"SELECT COUNT(*) FROM {table} WHERE source_quarter = %s", (quarter,))
    loaded = cur.fetchone()[0]
    rejected = file_rows - loaded

    cur.execute("DELETE FROM LOAD_LOG WHERE source_quarter = %s AND table_name = %s", (quarter, table))
    cur.execute(
        "INSERT INTO LOAD_LOG (source_quarter, table_name, file_rows, loaded_rows, rejected_rows) VALUES (%s, %s, %s, %s, %s)",
        (quarter, table, file_rows, loaded, rejected),
    )
    if loaded == 0 or abs(rejected) > file_rows * MAX_REJECTED_SHARE:
        raise RuntimeError(f"{quarter}/{name}: file has {file_rows} rows but {loaded} loaded. Refusing to commit.")
    return {"table": table, "file_rows": file_rows, "loaded_rows": loaded, "rejected_rows": rejected}


def load_quarter(quarter: str) -> dict:
    if not re.fullmatch(r"\d{4}q[1-4]", quarter):
        raise ValueError(f"quarter must look like 2025q1, got {quarter!r}")

    with tempfile.TemporaryDirectory() as tmp:
        zip_path = Path(tmp) / f"{quarter}.zip"
        size = download(quarter, zip_path)
        files = {}
        for name in ("sub", "num"):
            path = Path(tmp) / f"{name}.txt"
            header, rows = extract(zip_path, f"{name}.txt", path)
            files[name] = (path, header, rows)

        conn = connect()
        try:
            cur = conn.cursor()
            for name, (path, _, _) in files.items():
                # PUT uploads the file to the stage and gzips it on the way
                cur.execute(f"PUT 'file://{path.as_posix()}' @LANDING/{quarter}/ AUTO_COMPRESS = TRUE OVERWRITE = TRUE")
            cur.execute("BEGIN")
            results = [copy_table(cur, quarter, name, header, rows) for name, (_, header, rows) in files.items()]
            cur.execute("COMMIT")
        except Exception:
            conn.cursor().execute("ROLLBACK")      # all of the quarter, or none of it
            raise
        finally:
            conn.close()

    result = {"quarter": quarter, "zip_bytes": size, "tables": results}
    print(result)
    return result


if __name__ == "__main__":
    load_quarter(sys.argv[1])