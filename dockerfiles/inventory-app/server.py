from app import create_app

application = create_app()

if __name__ == "__main__":
    application.run(host=application.config["INVENTORY_HOST"],port=application.config["INVENTORY_PORT"])
