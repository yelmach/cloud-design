import requests
from flask import Blueprint, Response, current_app, jsonify, request


inventory_blueprint = Blueprint("inventory", __name__)

@inventory_blueprint.route("/api/movies", methods=["GET", "POST", "DELETE"], strict_slashes=False)
@inventory_blueprint.route("/api/movies/<int:movie_id>", methods=["GET", "PUT", "DELETE"], strict_slashes=False)
def forward_to_inventory(movie_id=None):
    base_url = current_app.config["INVENTORY_API_URL"]

    # Construct the target URL
    target_url = f"{base_url}/api/movies"
    if movie_id is not None:
        target_url = f"{target_url}/{movie_id}"

    try:
        # Forward the exact request to the Inventory API
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers={key: value for (key, value) in request.headers if key != "Host"},
            data=request.get_data(),
            cookies=request.cookies,
            params=request.args,
            allow_redirects=False
        )

        # Exclude hop-by-hop headers that shouldn't be forwarded to the client
        excluded_headers = ["content-encoding", "content-length", "transfer-encoding", "connection"]
        headers = [
            (name, value) for (name, value) in resp.raw.headers.items()
            if name.lower() not in excluded_headers
        ]

        # Return the exact response body, status code, and headers
        return Response(resp.content, resp.status_code, headers)

    except requests.exceptions.RequestException as e:
        current_app.logger.error(f"Failed to connect to Inventory API: {e}")
        return jsonify(error="Inventory service is currently unavailable"), 503