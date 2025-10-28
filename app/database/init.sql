-- TaskFlow Database Schema - Simplified Version
-- Focus: Kubernetes integration, not database optimization

DROP TABLE IF EXISTS tasks;

CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO tasks (title, completed) VALUES
    ('Learn Kubernetes', false),
    ('Deploy to OpenShift', false),
    ('Connect to database', false);

-- Verify initialization
SELECT 'Database initialized!' as status;
SELECT COUNT(*) as task_count FROM tasks;