from airflow.decorators import dag, task
from airflow.utils.dates import days_ago
from airflow.operators.python import get_current_context
from pprint import pprint
import os

@dag(schedule_interval=None, start_date=days_ago(2))
def block_etl():

    @task()
    def print_context():
        context = get_current_context()
        pprint(context)
        conf = context['dag_run'].conf
        client = conf.get('eth_client', os.environ['ETHEREUM_CLIENT'])
        print(f'ETHEREUM_CLIENT: {client}')
        return {'eth_client': client}

    @task()
    def print_subnet():
        subnet = os.environ['SUBNET_A']
        print(f'SUBNET_A: {subnet}')

    print_context()
    print_subnet()

block_etl_dag = block_etl()

