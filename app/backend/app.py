from flask import Flask, jsonify, request
from datetime import datetime
import os

app = Flask(__name__)

# Database imports (used when USE_DATABASE=true in Week 3)
try:
    import psycopg2
    from psycopg2 import pool
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False

# Database connection pool (activated in Week 3)
db_pool = None
USE_DATABASE = os.environ.get('USE_DATABASE', 'false').lower() == 'true'

if USE_DATABASE and PSYCOPG2_AVAILABLE:
    try:
        db_pool = psycopg2.pool.SimpleConnectionPool(
            minconn=1,
            maxconn=10,
            host=os.environ.get('DB_HOST', 'localhost'),
            database=os.environ.get('DB_NAME', 'taskflowdb'),
            user=os.environ.get('DB_USER', 'taskflowuser'),
            password=os.environ.get('DB_PASSWORD', 'taskflow123'),
            port=os.environ.get('DB_PORT', '5432')
        )
        print(f"Connected to database at {os.environ.get('DB_HOST')}")
    except Exception as e:
        print(f"Database connection failed: {e}")
        db_pool = None
        USE_DATABASE = False

# In-memory task storage (Week 1-2)
tasks = [
    {"id": 1, "title": "Learn Kubernetes", "completed": False, "created_at": "2024-10-01"},
    {"id": 2, "title": "Deploy to OpenShift", "completed": False, "created_at": "2024-10-02"}
]
next_id = 3

# Database helper functions
def get_db_connection():
    """Get connection from pool"""
    if db_pool:
        return db_pool.getconn()
    return None

def return_db_connection(conn):
    """Return connection to pool"""
    if db_pool and conn:
        db_pool.putconn(conn)

@app.route('/')
def home():
    return jsonify({
        "app": "TaskFlow API",
        "version": os.environ.get('APP_VERSION', '1.0'),
        "environment": os.environ.get('ENVIRONMENT', 'development')
    })

@app.route('/api')
def api_info():
    """API information endpoint"""
    db_status = "not configured"
    if USE_DATABASE:
        db_status = "connected" if db_pool else "connection failed"
    
    return jsonify({
        "service": "TaskFlow API",
        "version": os.environ.get('APP_VERSION', '1.0'),
        "environment": os.environ.get('ENVIRONMENT', 'development'),
        "database": db_status
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    health_status = {"status": "healthy"}
    
    if USE_DATABASE:
        if db_pool:
            try:
                conn = get_db_connection()
                if conn:
                    cur = conn.cursor()
                    cur.execute('SELECT 1')
                    cur.close()
                    return_db_connection(conn)
                    health_status["database"] = "connected"
                else:
                    health_status["database"] = "disconnected"
            except Exception as e:
                health_status["database"] = f"error: {str(e)}"
        else:
            health_status["database"] = "not configured"
    
    return jsonify(health_status), 200

@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    """Get all tasks"""
    if USE_DATABASE and db_pool:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT id, title, completed, created_at FROM tasks ORDER BY id')
            rows = cur.fetchall()
            cur.close()
            return_db_connection(conn)
            
            tasks_list = []
            for row in rows:
                tasks_list.append({
                    "id": row[0],
                    "title": row[1],
                    "completed": row[2],
                    "created_at": row[3].strftime('%Y-%m-%d') if row[3] else None
                })
            return jsonify(tasks_list)
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        # In-memory storage
        return jsonify(tasks)

@app.route('/api/tasks', methods=['POST'])
def create_task():
    """Create a new task"""
    global next_id
    data = request.get_json()
    
    if not data or not data.get('title'):
        return jsonify({"error": "Title is required"}), 400
    
    if USE_DATABASE and db_pool:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                'INSERT INTO tasks (title, completed) VALUES (%s, %s) RETURNING id, title, completed, created_at',
                (data.get('title'), False)
            )
            row = cur.fetchone()
            conn.commit()
            cur.close()
            return_db_connection(conn)
            
            task = {
                "id": row[0],
                "title": row[1],
                "completed": row[2],
                "created_at": row[3].strftime('%Y-%m-%d') if row[3] else None
            }
            return jsonify(task), 201
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        # In-memory storage
        task = {
            "id": next_id,
            "title": data.get('title'),
            "completed": False,
            "created_at": datetime.now().strftime('%Y-%m-%d')
        }
        tasks.append(task)
        next_id += 1
        return jsonify(task), 201

@app.route('/api/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    """Update a task"""
    data = request.get_json()
    
    if not data:
        return jsonify({"error": "Request body is required"}), 400
    
    if USE_DATABASE and db_pool:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            
            # Build update query
            updates = []
            params = []
            if 'completed' in data:
                updates.append('completed = %s')
                params.append(data['completed'])
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            
            if not updates:
                return jsonify({"error": "No fields to update"}), 400
            
            params.append(task_id)
            query = f"UPDATE tasks SET {', '.join(updates)} WHERE id = %s RETURNING id, title, completed, created_at"
            
            cur.execute(query, params)
            row = cur.fetchone()
            conn.commit()
            
            if not row:
                cur.close()
                return_db_connection(conn)
                return jsonify({"error": "Task not found"}), 404
            
            cur.close()
            return_db_connection(conn)
            
            task = {
                "id": row[0],
                "title": row[1],
                "completed": row[2],
                "created_at": row[3].strftime('%Y-%m-%d') if row[3] else None
            }
            return jsonify(task)
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        # In-memory storage
        for task in tasks:
            if task['id'] == task_id:
                task['completed'] = data.get('completed', task['completed'])
                if data.get('title'):
                    task['title'] = data.get('title')
                return jsonify(task)
        
        return jsonify({"error": "Task not found"}), 404

@app.route('/api/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task"""
    global tasks
    
    if USE_DATABASE and db_pool:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('DELETE FROM tasks WHERE id = %s', (task_id,))
            deleted = cur.rowcount
            conn.commit()
            cur.close()
            return_db_connection(conn)
            
            if deleted > 0:
                return '', 204
            return jsonify({"error": "Task not found"}), 404
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        # In-memory storage
        initial_length = len(tasks)
        tasks = [t for t in tasks if t['id'] != task_id]
        
        if len(tasks) < initial_length:
            return '', 204
        return jsonify({"error": "Task not found"}), 404

if __name__ == '__main__':
    mode = "database" if USE_DATABASE else "in-memory"
    print(f"Starting TaskFlow API in {mode} mode")
    app.run(host='0.0.0.0', port=8080)# CI/CD test - Mon Oct 13 08:37:07 EDT 2025
