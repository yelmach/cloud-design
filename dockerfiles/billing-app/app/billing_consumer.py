import pika
import json
import time
from sqlalchemy.exc import SQLAlchemyError
from .database import db, Order

def callback(ch, method, properties, body):
	try:
		payload = json.loads(body)
		
		order = Order(
			user_id=int(payload['user_id']),
			number_of_items=int(payload['number_of_items']),
			total_amount=int(payload['total_amount'])
		)
		
		db.session.add(order)
		db.session.commit()
		ch.basic_ack(delivery_tag=method.delivery_tag)
		
	except (json.JSONDecodeError, KeyError, ValueError) as e:
		ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
		
	except SQLAlchemyError as e:
		db.session.rollback()
		ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

def start_consuming(app):
    credentials = pika.PlainCredentials(
        app.config['RABBITMQ_USER'], 
        app.config['RABBITMQ_PASSWORD']
    )
    
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(
            host=app.config['RABBITMQ_HOST'],
            port=app.config['RABBITMQ_PORT'],
            credentials=credentials
        )
    )
    
    channel = connection.channel()
    
    channel.queue_declare(queue=app.config['RABBITMQ_QUEUE'], durable=True)
    
    def ctx_callback(ch, method, properties, body):
        with app.app_context():
            callback(ch, method, properties, body)

    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue=app.config['RABBITMQ_QUEUE'], on_message_callback=ctx_callback)
    channel.start_consuming()