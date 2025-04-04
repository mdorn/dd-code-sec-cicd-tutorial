from flask import Flask, request, jsonify
import time
import random
import sqlite3

VERSION=1
app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({
        'app_version': VERSION,
        'endpoints': [
            '/user?id=',
            '/random'
        ]
    })


@app.route('/user')
def get_records():
    '''Function intentionally vulnerable to SQL injection'''
    uid = request.args.get('id')
    conn = sqlite3.connect(':memory:')
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)')
    cursor.execute("INSERT INTO users (username, password) VALUES ('foo', 'P@ssw0rd#')")
    cursor.execute("INSERT INTO users (username, password) VALUES ('bar', 'S3cr3t!')")
    # SQLi example: http://localhost:5000/users?id=1%20OR%201=1
    cursor.execute("SELECT * FROM users WHERE id={}".format(uid))  # VULNERABLE
    # cursor.execute("SELECT * FROM users WHERE id= ?", [uid])  NOT VULNERABLE: parameterized query
    result = jsonify(cursor.fetchall())
    conn.close()
    return result


@app.route('/random')
def get_random_numbers():
    '''Function with intentional misuse of random.randrange function'''
    id = 1
    # sql = f"SELECT id,description FROM notes WHERE id = {id}"
    numbers = [random.randrange(10) for _ in range(10)]  # VULNERABLE
    # numbers = [random.randint(0, 5) for _ in range(10)]  # NOT VULNERABLE - better yet, use secrets module
    response = {
        "data": {"random_number": numbers},
        "message": "success"
    }
    return jsonify(response)


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
