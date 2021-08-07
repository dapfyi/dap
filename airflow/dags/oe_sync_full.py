from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.python import PythonOperator
from pprint import pprint

with DAG('oe_sync_full', schedule_interval=None, start_date=days_ago(2)) as dag:

    def print_context(ds, **kwargs):
        print(ds)
        pprint(kwargs['dag_run'].conf.get('param'))
        return 'see you in logs'

    run_this = PythonOperator(
        task_id='print_context',
        python_callable=print_context,
    )

