import pika
import json
from flask import Blueprint, request, current_app, jsonify

billing_blueprint = Blueprint("billing", __name__)

@billing_blueprint.route("/api/billing", methods=["POST"], strict_slashes=False)
def publish_billing_message():
    if not request.is_json:
        return jsonify(error="Request body must be JSON"), 400

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify(error="Request body must be a JSON object"), 400

    try:
        credentials = pika.PlainCredentials(
            current_app.config["RABBITMQ_USER"],
            current_app.config["RABBITMQ_PASSWORD"]
        )
        
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(
                host=current_app.config["RABBITMQ_HOST"],
                port=current_app.config["RABBITMQ_PORT"],
                credentials=credentials
            )
        )
        channel = connection.channel()
        channel.queue_declare(queue=current_app.config["RABBITMQ_QUEUE"], durable=True)
        channel.basic_publish(
            exchange="",
            routing_key=current_app.config["RABBITMQ_QUEUE"],
            body=json.dumps(payload),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        
        connection.close()
        
        return jsonify(message="Message posted"), 200

    except Exception as e:
        current_app.logger.error(f"RabbitMQ connection error: {e}")
        return jsonify(error="Failed to enqueue billing message"), 500