from flask import Flask, jsonify
from sqlalchemy.exc import SQLAlchemyError

from .movie_routes import movies_blueprint
from .config import Config
from .database import db


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    db.init_app(app)

    app.register_blueprint(movies_blueprint)

    @app.errorhandler(400)
    def handle_bad_request(error):
        return jsonify(error=error.description or "Bad request"), 400

    @app.errorhandler(404)
    def handle_not_found(error):
        return jsonify(error="Not found"), 404

    @app.errorhandler(SQLAlchemyError)
    def handle_database_error(error):
        db.session.rollback()
        app.logger.exception("Database operation failed")
        return jsonify(error="Database operation failed"), 500

    with app.app_context():
        db.create_all()

    return app
