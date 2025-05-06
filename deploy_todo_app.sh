#!/bin/bash
set -e

# Application directory on EC2 - ALIGNED WITH appspec.yml destination
# CodeDeploy deploys the artifact to /home/ubuntu/my-python-app-deploy
APP_DIR=/home/ubuntu/my-python-app-deploy
VENV_DIR=$APP_DIR/venv

# Update emojis for better visibility in logs
echo "🔄 Updating system packages..."
# Using -qq disables output except for errors, making logs cleaner if successful
sudo apt update -qq -y
sudo apt install python3 python3-pip python3-venv -qq -y

echo "📁 Setting up application directories..."
# Create the base APP_DIR first (it might already exist from CodeDeploy copy)
mkdir -p $APP_DIR
# Create the templates directory inside the APP_DIR
mkdir -p $APP_DIR/templates # Ensuring templates subdir exists where app.py expects it

echo "🔒 Creating virtual environment..."
# Use --clear for a fresh environment.
# Keep --system-site-packages for now as it was in your original script,
# but evaluate removing it later as part of the broader CI/CD strategy
python3 -m venv $VENV_DIR --clear --system-site-packages || { echo "Error creating venv"; exit 1; }


echo "📦 Installing dependencies inside virtualenv..."
source $VENV_DIR/bin/activate || { echo "Error activating venv"; exit 1; }
$VENV_DIR/bin/pip install --upgrade pip || { echo "Error upgrading pip"; exit 1; }
# Pin Flask version for consistency (using version from your logs)
$VENV_DIR/bin/pip install flask==3.1.0 || { echo "Error installing flask"; exit 1; }
# Install from requirements.txt if it exists
if [ -f requirements.txt ]; then
    $VENV_DIR/bin/pip install -r requirements.txt || { echo "Error installing requirements.txt"; exit 1; }
fi
deactivate # Deactivate venv after installation


# --- Start Debugging and File Copy ---
echo "--- Debugging File Copy ---"
echo "Current working directory (should be CodeDeploy's deployment dir): $(pwd)"
echo "Listing contents of current directory ($(pwd)):"
ls -la $PWD/

echo "Listing contents of the 'app' subdirectory ($(pwd)/app/):"
# Use find as ls -la might fail if 'app/' doesn't exist
find $PWD/app/ -maxdepth 1 -print || echo "Warning: Could not list contents of $PWD/app/ (directory might be missing or empty)"

echo "Intended application destination directory (APP_DIR): $APP_DIR"
echo "--- End Debugging File Copy ---"


echo "📝 Copying application files..."
# CodeDeploy sets the working directory to the deployment destination (/home/ubuntu/my-python-app-deploy)
# So, source files like 'app/app.py' are relative to this working directory.
# Copy app.py from the working directory's 'app' subdir to the root of APP_DIR
cp "$PWD/app/app.py" "$APP_DIR/" || { echo "Error copying app/app.py"; exit 1; }
# Copy contents of app/templates from working dir to APP_DIR/templates
cp -r "$PWD/app/templates/"* "$APP_DIR/templates/" || { echo "Error copying app/templates"; exit 1; }

# Note: Other files like appspec.yml, buildspec.yml, deploy_todo_app.sh, requirements.txt
# were copied by CodeDeploy automatically to $APP_DIR because source: / was used in appspec.yml.
# They are available at $APP_DIR/filename if needed later in the script.
# Example: $APP_DIR/requirements.txt


echo "🚀 Restarting the Flask application..."
# Terminate any existing process associated with the app.py path in APP_DIR
# Use the full path to app.py within the deployment directory
sudo pkill -f "$APP_DIR/app.py" 2>/dev/null || true

# Start the application with nohup
# Use the full path to the python interpreter in the venv within APP_DIR
nohup $VENV_DIR/bin/python "$APP_DIR/app.py" > "$APP_DIR/app.log" 2>&1 &

# Verify the application is running
PID=$!
sleep 5 # Give the app a bit more time to start
if ps -p $PID > /dev/null; then
    echo "✅ Application started successfully with PID: $PID"
    # Adjust the URL message to use the correct APP_DIR path for logs
    echo "✅ Check logs at $APP_DIR/app.log"
    echo "✅ Deployment complete! Visit: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/"
else
    echo "❌ Application failed to start. Check logs at $APP_DIR/app.log"
    exit 1
fi
