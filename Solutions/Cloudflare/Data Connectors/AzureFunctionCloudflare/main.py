import os
import asyncio
from azure.storage.blob.aio import ContainerClient
import json
import logging
import azure.functions as func
import re
import time

from .sentinel_connector_async import AzureSentinelConnectorAsync


logging.getLogger('azure.core.pipeline.policies.http_logging_policy').setLevel(logging.ERROR)


MAX_SCRIPT_EXEC_TIME_MINUTES = 5


AZURE_STORAGE_CONNECTION_STRING = os.environ['AZURE_STORAGE_CONNECTION_STRING']
CONTAINER_NAME = os.environ['CONTAINER_NAME']
WORKSPACE_ID = os.environ['WORKSPACE_ID']
SHARED_KEY = os.environ['SHARED_KEY']
LOG_TYPE = 'Cloudflare'


MAX_FILES_COUNT_PER_PAGE = 50
MAX_CONCURRENT_PROCESSING_FILES = 25


LOG_ANALYTICS_URI = os.environ.get('logAnalyticsUri')

if not LOG_ANALYTICS_URI or str(LOG_ANALYTICS_URI).isspace():
    LOG_ANALYTICS_URI = 'https://' + WORKSPACE_ID + '.ods.opinsights.azure.com'

pattern = r'https:\/\/([\w\-]+)\.ods\.opinsights\.azure.([a-zA-Z\.]+)$'
match = re.match(pattern, str(LOG_ANALYTICS_URI))
if not match:
    raise Exception("Invalid Log Analytics Uri.")


async def main(mytimer: func.TimerRequest):
    logging.info('Starting script')
    conn = AzureBlobStorageConnector(AZURE_STORAGE_CONNECTION_STRING, CONTAINER_NAME, queue_max_size=MAX_CONCURRENT_PROCESSING_FILES)
    container_client = conn._create_container_client()
    async with container_client:
        cors = []
        async for blob in conn.get_blobs():
            cor = conn.process_blob(blob, container_client)
            cors.append(cor)
            if len(cors) >= MAX_FILES_COUNT_PER_PAGE:
                await asyncio.gather(*cors)
                cors = []
                logging.info('Processed {} files with {} events.'.format(conn.total_blobs, conn.total_events))
                if conn.check_if_script_runs_too_long():
                    logging.info('Script is running too long. Stop processing new blobs.')
                    break

        if cors:
            await asyncio.gather(*cors)
            logging.info('Processed {} files with {} events.'.format(conn.total_blobs, conn.total_events))

    logging.info('Script finished. Processed files: {}. Processed events: {}'.format(conn.total_blobs, conn.total_events))

class AzureBlobStorageConnector:
    def __init__(self, conn_string, container_name, queue_max_size=20):
        self.__conn_string = conn_string
        self.__container_name = container_name
        self.semaphore = asyncio.Semaphore(queue_max_size)
        self.script_start_time = int(time.time())
        self.total_blobs = 0
        self.total_events = 0

    def _create_container_client(self):
        return ContainerClient.from_connection_string(self.__conn_string, self.__container_name, logging_enable=False)

    def _create_sentinel_client(self):
        return AzureSentinelConnectorAsync(LOG_ANALYTICS_URI, WORKSPACE_ID, SHARED_KEY, LOG_TYPE, queue_size=10000)

    async def get_blobs(self):
        container_client = self._create_container_client()
        async with container_client:
            async for blob in container_client.list_blobs():
                if 'ownership-challenge' not in blob['name']:
                    yield blob

    def check_if_script_runs_too_long(self):
        now = int(time.time())
        duration = now - self.script_start_time
        max_duration = int(MAX_SCRIPT_EXEC_TIME_MINUTES * 60 * 0.85)
        return duration > max_duration

    async def delete_blob(self, blob, container_client):
        logging.debug("Deleting blob {}".format(blob['name']))
        await container_client.delete_blob(blob['name'])

    async def process_blob(self, blob, container_client):
        async with self.semaphore:
            logging.debug("Start processing {}".format(blob['name']))
            sentinel = self._create_sentinel_client()
            blob_cor = await container_client.download_blob(blob['name'])
            s = ''
            async for chunk in blob_cor.chunks():
                s += chunk.decode()
                lines = s.splitlines()
                for n, line in enumerate(lines):
                    if n < len(lines) - 1:
                        if line:
                            event = json.loads(line)
                            await sentinel.send(event)
                s = line
            if s:
                event = json.loads(s)
                await sentinel.send(event)
            await sentinel.flush()
            await self.delete_blob(blob, container_client)
            self.total_blobs += 1
            self.total_events += sentinel.successfull_sent_events_number
            logging.debug("Finish processing {}. Sent events: {}".format(blob['name'], sentinel.successfull_sent_events_number))
