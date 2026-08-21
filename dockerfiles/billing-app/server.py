import threading

from app import create_app
from app.billing_consumer import start_consuming

app = create_app()

if __name__ == "__main__":
    consumer = threading.Thread(target=start_consuming, args=(app,), daemon=True)
    consumer.start()
    app.run(
        host=app.config["BILLING_HOST"],
        port=app.config["BILLING_PORT"],
        use_reloader=False,
    )
