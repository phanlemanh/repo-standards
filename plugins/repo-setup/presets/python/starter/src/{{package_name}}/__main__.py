import os

from .greet import greet

if __name__ == "__main__":
    print(greet(os.environ.get("APP_NAME", "")))
