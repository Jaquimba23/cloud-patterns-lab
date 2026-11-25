import json


def lambda_handler(event, context):
    """Responde a las peticiones que llegan desde API Gateway (HTTP API)."""
    path = event.get("rawPath", "/")
    metodo = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    cuerpo = {
        "mensaje": "Hola desde Lambda a través de API Gateway",
        "ruta": path,
        "metodo": metodo,
    }
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(cuerpo, ensure_ascii=False),
    }
