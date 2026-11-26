"""Quarterly load of the SEC financial statement data sets into Snowflake, followed by dbt build."""
from datetime import datetime, timedelta, timezone

from airflow.sdk import Param, dag, task


def previous_quarter(day: datetime) -> str:
    """The run on 15 April 2025 loads 2025q1; the run on 15 January 2025 loads 2024q4."""
    quarter = (day.month - 1) // 3          # 0 for Jan-Mar, 1 for Apr-Jun ...
    year = day.year if quarter > 0 else day.year - 1
    return f"{year}q{quarter if quarter > 0 else 4}"


@dag(
    dag_id="filings_quarterly",
    schedule="0 6 15 1,4,7,10 *",         # 06:00 UTC on the 15th of the month after each quarter ends
    start_date=datetime(2024, 1, 1),
    catchup=False,                        # history is loaded deliberately with a backfill, not by accident
    max_active_runs=1,                    # one quarter at a time
    default_args={"retries": 2, "retry_delay": timedelta(minutes=10)},
    params={"quarter": Param("", type="string", description="For example 2025q1. Leave empty to follow the schedule.")},
    tags=["filings"],
)
def filings_quarterly():

    @task
    def load_raw(params=None, logical_date=None) -> dict:
        from include.load_quarter import load_quarter

        run_date = logical_date or datetime.now(timezone.utc)
        return load_quarter(params["quarter"] or previous_quarter(run_date))

    load_raw()


filings_quarterly()