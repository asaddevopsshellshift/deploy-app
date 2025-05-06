#!/bin/bash
set -e

# Application directory on EC2
APP_DIR=/home/ubuntu/my-python-app-deploy
VENV_DIR=$APP_DIR/venv

# Update emojis for better visibility in logs
echo "🔄 Updating system packages..."
sudo apt update -y
sudo apt install python3 python3-pip python3-venv -y

echo "📁 Setting up application directories..."
mkdir -p $APP_DIR/templates

echo "🔒 Creating virtual environment..."
# Add the --clear flag to ensure a fresh environment
# Add system-site-packages to prevent conflicts with system Python
python3 -m venv $VENV_DIR --clear --system-site-packages

echo "📦 Installing dependencies inside virtualenv..."
source $VENV_DIR/bin/activate
$VENV_DIR/bin/pip install --upgrade pip
$VENV_DIR/bin/pip install flask
# Install from requirements.txt if it exists
if [ -f requirements.txt ]; then
    $VENV_DIR/bin/pip install -r requirements.txt
fi

echo "📝 Copying application files..."
cp app/app.py $APP_DIR/
cp -r app/templates/* $APP_DIR/templates/

echo "🚀 Restarting the Flask application..."
# Terminate any existing process
sudo pkill -f "$APP_DIR/app.py" 2>/dev/null || true

# Start the application with nohup
nohup $VENV_DIR/bin/python $APP_DIR/app.py > $APP_DIR/app.log 2>&1 &

# Verify the application is running
PID=$!
sleep 2
if ps -p $PID > /dev/null; then
    echo "✅ Application started successfully with PID: $PID"
    echo "✅ Deployment complete! Visit: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/"
else
    echo "❌ Application failed to start. Check logs at $APP_DIR/app.log"
    exit 1
fi
```# CI/CD Integration Strategy for AWS CodeBuild

## Immediate Issue Resolution

### Problem: Python Module Naming Conflict in Build Environment
Your build is failing with an error related to a naming conflict with Python's standard library module `typing`. According to the error message, there's a conflict at: `/tmp/codebuild/output/src1859779718/src/typing.py`.

However, this file doesn't exist in your repository structure. This suggests one of these possibilities:
1. The file is being created during the build process
2. There might be an issue with how CodeBuild is setting up the environment
3. A dependency might be causing the conflict

### Solution:
1. **Check your requirements.txt**:
   - Review dependencies for any that might create a `typing.py` file
   - Ensure version pinning for all dependencies

2. **Modify your buildspec.yml**:
   - Add debugging steps to see what files exist in the directory before virtual environment creation
   - Use a different approach for creating the virtual environment

## CI/CD Integration Enhancement Strategy

### 1. Standardize Development Environment

- **Create a consistent development environment with virtualenv**:
  ```bash
  # setup.sh - Development environment setup script
  #!/bin/bash
  
  # Create and activate virtual environment
  python3 -m venv venv --system-site-packages
  source venv/bin/activate
  
  # Install dependencies
  pip install --upgrade pip
  pip install flask pytest
  
  # If you have a requirements.txt file
  if [ -f requirements.txt ]; then
    pip install -r requirements.txt
  fi
  
  echo "Development environment setup complete!"
