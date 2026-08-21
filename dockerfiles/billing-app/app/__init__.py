from flask import Flask, jsonify
from .config import Config
from .database import db

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    db.init_app(app)

    @app.get("/health")
    def healthcheck():
        return jsonify(status="ok"), 200

    with app.app_context():
        db.create_all()

    return app
