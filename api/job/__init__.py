import azure.functions as func
from azure.identity import EnvironmentCredential
from azure.mgmt.automation import AutomationClient
import json
import logging
import os
import requests
from urllib.parse import urlparse, parse_qs

# env variables used by the SDK to access the Automation account
SUBSCRIPTION_ID = os.environ.get("AZURE_SUBSCRIPTION_ID", None)
GROUP_NAME = os.environ.get("AUTOMATION_GROUP_NAME", None)
ACCOUNT_NAME = os.environ.get("AUTOMATION_ACCOUNT_NAME", None)

def get_status(client, id):
    job = client.job.get(GROUP_NAME, ACCOUNT_NAME, id)
    response = {'id': id, 'status': job.status, 'exception': job.exception}
    return response

def get_output(client, id):
    streams = client.job_stream.list_by_job(GROUP_NAME, ACCOUNT_NAME, id)

    output = []
    warnings = []
    errors = []

    for job_stream in streams:
        if job_stream.stream_type == 'Output':
            output.append(job_stream.summary)
        if job_stream.stream_type == 'Warning':
            warnings.append(job_stream.summary)
        if job_stream.stream_type == 'Error':
            errors.append(job_stream.summary)
    
    response = {'output': output, 'warnings': warnings, 'errors': errors}
    return response

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info(f'HTTP trigger processed a request. Method: {req.method}, URL: {req.url}')

    action = req.route_params.get('action')
    id = req.route_params.get('id')
    response = None

    try:
        if action == 'submit':
            try:
                webhook_data = req.get_json()
            except ValueError:
                webhook_data = None

            # JSON sent in the request body must include the "webhookName" property to locate the webhook URL
            webhook_name = webhook_data.get('webhookName', '')
            url = urlparse(os.environ.get('WEBHOOK_'+webhook_name, None))

            webhook_url = f"https://{url.netloc}{url.path}"
            webhook_token = parse_qs(url.query)['token'][0]
            webhook_params = {
                # the Azure portal provides the webhook URL with URL encoding, so decode here
                'token': webhook_token
            }

            webhook_response = requests.request('POST', webhook_url, params=webhook_params, json=webhook_data)
            # response to the webhook POST is JSON formatted containing the Automation job ID
            response = webhook_response.text

        elif action == 'status':
            if id != None:
                client = AutomationClient(credential=EnvironmentCredential(), subscription_id=SUBSCRIPTION_ID)
                status_response = get_status(client, id)
                response = json.dumps(status_response)
                client.close()

        elif action == 'output':
            if id != None:
                client = AutomationClient(credential=EnvironmentCredential(), subscription_id=SUBSCRIPTION_ID)
                output_response = get_output(client, id)
                response = json.dumps(output_response)
                client.close()
        
        elif action == 'details':
            if id != None:
                client = AutomationClient(credential=EnvironmentCredential(), subscription_id=SUBSCRIPTION_ID)
                status_response = get_status(client, id)
                output_response = get_output(client, id)

                response = json.dumps(status_response | output_response)
                client.close()
        else:
            status_code = 404

        return func.HttpResponse(response, status_code=200, mimetype='application/json')

    except Exception as e:
        response = json.dumps({'error': repr(e)})
        return func.HttpResponse(response, status_code=500, mimetype='application/json')
