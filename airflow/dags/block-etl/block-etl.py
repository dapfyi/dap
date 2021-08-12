from airflow.decorators import dag, task
from airflow.utils.dates import days_ago
from airflow.operators.python import get_current_context
from pprint import pprint

@dag(schedule_interval=None, start_date=days_ago(2))
def block_etl():
    @task()
    def print_context():
        context = get_current_context()
        pprint(context)
        conf = context['dag_run'].conf
        tag = conf.get('tag', 'bgeth')  # instance selector
        return {'tag': tag}
    print_context()

block_etl_dag = block_etl()

