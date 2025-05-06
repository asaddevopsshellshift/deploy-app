#!/bin/bash

APP_DIR=~/my-python-app
VENV_DIR=$APP_DIR/venv

echo "🔄 Updating system..."
sudo apt update -y
sudo apt install python3 python3-pip python3-venv -y

echo "📁 Setting up application directories..."
mkdir -p $APP_DIR/templates

echo "🔒 Creating virtual environment..."
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

echo "📦 Installing Flask inside virtualenv..."
$VENV_DIR/bin/pip install --upgrade pip
$VENV_DIR/bin/pip install flask

echo "📝 Copying Flask app..."
cp app/app.py $APP_DIR/
cp -r app/templates/* $APP_DIR/templates/

echo "🚀 Starting the Flask app on port 8080..."
sudo pkill -f "$APP_DIR/app.py" 2>/dev/null
nohup $VENV_DIR/bin/python $APP_DIR/app.py > $APP_DIR/app.log 2>&1 &

echo "✅ Deployment complete! Visit: http://your-ec2-public-ip:8080/"
