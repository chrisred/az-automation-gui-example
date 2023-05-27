import logging
import azure.functions as func

def main(req: func.HttpRequest, data) -> func.HttpResponse:
    logging.info(f'HTTP trigger processed a request. Method: {req.method}, URL: {req.url}')

    return func.HttpResponse(data, status_code=200, mimetype='application/json')
