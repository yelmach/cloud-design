from flask import Blueprint, jsonify, request
from . import movie_repository

movies_blueprint = Blueprint("movies", __name__)

def _json_object():
    if not request.is_json:
        return None, "Request body must be JSON"

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return None, "Request body must be a JSON object"
    return payload, None


def _validate_field(payload, field, required):
    if field not in payload:
        if required:
            return None, f"{field} is required"
        return None, None

    value = payload[field]
    if not isinstance(value, str) or not value.strip():
        return None, f"{field} must be a non-empty string"

    value = value.strip()
    if field == "title" and len(value) > 255:
        return None, "title must not exceed 255 characters"

    return value, None


@movies_blueprint.route("/api/movies", methods=["GET", "POST", "DELETE"], strict_slashes=False)
def movies_collection():
    if request.method == "GET":
        title = request.args.get("title")
        if title is not None:
            title = title.strip()
            if not title:
                return jsonify(error="title must be a non-empty string"), 400

        movies = movie_repository.get_all(title=title)
        return jsonify([movie.to_dict() for movie in movies]), 200

    if request.method == "POST":
        payload, error = _json_object()
        if error:
            return jsonify(error=error), 400

        title, error = _validate_field(payload, "title", required=True)
        if error:
            return jsonify(error=error), 400
        
        description, error = _validate_field(payload, "description", required=True)
        if error:
            return jsonify(error=error), 400

        movie = movie_repository.create(title, description)
        return jsonify(movie.to_dict()), 201

    deleted_count = movie_repository.delete_all()
    return jsonify(message="All movies deleted", deleted_count=deleted_count), 200


@movies_blueprint.route("/api/movies/<int:movie_id>", methods=["GET", "PUT", "DELETE"], strict_slashes=False)
def movie_item(movie_id):
    movie = movie_repository.get_by_id(movie_id)
    if movie is None:
        return jsonify(error="Movie not found"), 404

    if request.method == "GET":
        return jsonify(movie.to_dict()), 200

    if request.method == "PUT":
        payload, error = _json_object()
        if error:
            return jsonify(error=error), 400
        
        if "title" not in payload and "description" not in payload:
            return jsonify(error="At least one of title or description is required"), 400

        title, error = _validate_field(payload, "title", required=False)
        if error:
            return jsonify(error=error), 400
        
        description, error = _validate_field(payload, "description", required=False)
        if error:
            return jsonify(error=error), 400

        movie = movie_repository.update(movie, title=title, description=description)
        return jsonify(movie.to_dict()), 200

    movie_repository.delete(movie)
    return jsonify(message="Movie deleted"), 200
