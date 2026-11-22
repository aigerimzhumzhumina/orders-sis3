import json, os, uuid
import boto3
from flask import Flask, request, jsonify

app = Flask(__name__)
sns = boto3.client("sns")
TOPIC_ARN = os.environ["TOPIC_ARN"]

@app.get("/health")
def health():
    return "ok", 200

@app.post("/orders")
def create_order():
    body = request.get_json(force=True)
    order = {
        "orderId": body.get("orderId") or str(uuid.uuid4()),
        "item": body["item"],
        "qty": int(body.get("qty", 1)),
    }
    sns.publish(TopicArn=TOPIC_ARN, Message=json.dumps(order), Subject="OrderCreated")
    return jsonify(order), 202
