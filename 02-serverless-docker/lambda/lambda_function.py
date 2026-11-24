import json
import logging
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Se ejecuta cada vez que se sube un archivo al bucket S3."""
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"].get("size", 0)
        logger.info("NUEVO ARCHIVO: s3://%s/%s (%s bytes)", bucket, key, size)
    return {"statusCode": 200, "body": json.dumps("procesado")}
