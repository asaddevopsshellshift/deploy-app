#!/bin/bash
set -e

# Application directory on EC2 - ALIGNED WITH appspec.yml destination
# CodeDeploy deploys the artifact to /home/ubuntu/my-python-app-deploy
APP_DIR=/home/ubuntu/my-python-app-deploy
VENV_DIR=$APP_DIR/venv

# --- Initial Debugging ---
echo "--- Initial Debugging ---"
echo "Starting working directory reported by CodeDeploy: $(pwd)"
echo "Intended application destination directory (APP_DIR): $APP_DIR"
echo "--- End Initial Debugging ---"

# CHANGE WORKING DIRECTORY TO THE DEPLOYMENT DESTINATION
# This is where CodeDeploy copied the application files
echo "Changing working directory to deployment destination: $APP_DIR"
cd "$APP_DIR" || { echo "Error changing directory to $APP_DIR"; exit 1; }


# --- Post-cd Debugging ---
echo "--- Post-cd Debugging ---"
echo "Current working directory AFTER cd: $(pwd)"
echo "Listing contents of the deployment directory ($(pwd)):"
ls -la $PWD/

echo "Listing contents of the 'app' subdirectory ($(pwd)/app/):"
# Use find as ls -la might fail if 'app/' doesn't exist, providing clearer output
find $PWD/app/ -maxdepth 1 -print || echo "Warning: Could not list contents of $PWD/app/ (directory might be missing or empty after copy)"
echo "--- End Post-cd Debugging ---"


# Update system packages (Consider doing this in User Data or a BeforeInstall hook)
echo "🔄 Updating system packages..."
sudo apt update -qq -y || { echo "Error updating packages"; exit 1; }
sudo apt install python3 python3-pip python3-venv -qq -y || { echo "Error installing python packages"; exit 1; }


echo "📁 Ensuring application directories are set up within $APP_DIR..."
# CodeDeploy should have copied 'app' and 'app/templates', but mkdir -p is safe
mkdir -p "$APP_DIR/templates" # Ensures templates subdir exists inside APP_DIR


echo "🔒 Creating virtual environment inside $APP_DIR..."
# --- REMOVED --system-site-packages for better isolation ---
python3 -m venv "$VENV_DIR" --clear || { echo "Error creating venv at $VENV_DIR"; exit 1; }


echo "📦 Installing dependencies inside virtualenv..."
# Activate the venv relative to the current working directory ($APP_DIR)
source "$VENV_DIR/bin/activate" || { echo "Error activating venv"; exit 1; }

# Use the pip binary directly from the venv for clarity and robustness
"$VENV_DIR/bin/pip" install --upgrade pip || { echo "Error upgrading pip"; exit 1; }

# --- INSTALL DEPENDENCIES ONLY FROM requirements.txt ---
# This is the SOLE source for Python package dependencies
echo "Attempting to install dependencies from requirements.txt located at: $PWD/requirements.txt"
if [ -f "requirements.txt" ]; then # Check for requirements.txt in the current directory ($APP_DIR)
    # Use -v for verbose output from pip to see *exactly* what it's doing
    "$VENV_DIR/bin/pip" install -v -r requirements.txt || { echo "Error installing requirements.txt"; exit 1; }
else
    echo "Error: requirements.txt not found in $APP_DIR. Cannot install dependencies."
    exit 1 # Exit with error if requirements.txt is missing
fi

# --- Debug: List installed packages ---
echo "--- Debug: Installed Python packages in VENV ---"
"$VENV_DIR/bin/pip" list || { echo "Error listing installed packages"; exit 1; }
echo "--- End Debug: Installed Python packages in VENV ---"
# -------------------------------------

deactivate # Deactivate venv after installation


# --- REDUNDANT FILE COPYING SECTION REMAINS REMOVED ---
# CodeDeploy's appspec.yml files: section already copied these files to $APP_DIR.
# The cp commands here are no longer needed as we are operating *within* $APP_DIR.
# ----------------------------------------------------


echo "🚀 Restarting the Flask application..."
# Terminate any existing process associated with the app.py path in APP_DIR
# Use the full path to app.py within the deployment directory
sudo pkill -f "$APP_DIR/app.py" 2>/dev/null || true

# Start the application with nohup
# Ensure nohup binary is available (usually is)
# Use the python interpreter from the venv and app.py from the current directory ($APP_DIR)
# Use the full path to app.py relative to root if needed, but relative to current dir ($APP_DIR) is 'app/app.py'
nohup "$VENV_DIR/bin/python" "app/app.py" > "$APP_DIR/app.log" 2>&1 &

# Verify the application is running
PID=$!
sleep 5 # Give the app a bit more time to start
if ps -p $PID > /dev/null; then
    echo "✅ Application started successfully with PID: $PID"
    # Adjust the URL message to use the correct APP_DIR path for logs
    echo "✅ Check logs at $APP_DIR/app.log"
    # Note: The IP address is the instance's *private* IP usually. Public IP requires metadata service.
    echo "✅ Deployment complete! Visit: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/ (Public IP, requires internet access)"
    echo "✅ Deployment complete! Application is running on port 8080." # More general message
else
    echo "❌ Application failed to start. Check logs at /home/ubuntu/my-python-app-deploy/app.log"
    # Print the log content directly for quicker debugging
    echo "--- Start of $APP_DIR/app.log ---"
    # Use `cat -n` to include line numbers for easier debugging of the app.log content
    cat -n "$APP_DIR/app.log"
    echo "--- End of $APP_DIR/app.log ---"
    exit 1
fi
