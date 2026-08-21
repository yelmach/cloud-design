from app import create_app


application = create_app()


if __name__ == "__main__":
    application.run(
        host=application.config["GATEWAY_HOST"],
        port=application.config["GATEWAY_PORT"],
    )
