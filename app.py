from flask import Flask
import time
import random

VERSION=1

app = Flask(__name__)

@app.route('/')
def index():
    return "App version {}".format(VERSION)

@app.route('/time')
def get_current_time():
    timestamp = str(int(time.time()))
    response = {
        "data": {"unix_timestamp": timestamp},
        "message": "success"
    }
    return response


@app.route('/random')
def get_random_numbers():
    id = 1
    # sql = f"SELECT id,description FROM notes WHERE id = {id}"
    # numbers = [random.random() for _ in range(10)]
    numbers = [random.randint(0, 5) for _ in range(10)]
    response = {
        "data": {"random_number": numbers},
        "message": "success"
    }
    return response


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
