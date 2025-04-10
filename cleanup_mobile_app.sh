#!/bin/bash
# Cleanup script to remove redundant Firebase configuration files from mobile_app directory

echo "Smart Plug App - Firebase Configuration Cleanup"
echo "================================================"
echo "This script will remove redundant Firebase configuration files from the mobile_app directory."
echo "Firebase configuration files in the root directory will be used instead."
echo

# Check if files exist
if [ -f "mobile_app/firebase.json" ]; then
  echo "Found mobile_app/firebase.json - Will be removed"
fi

if [ -f "mobile_app/firestore.rules" ]; then
  echo "Found mobile_app/firestore.rules - Will be removed"
fi

if [ -f "mobile_app/firestore.indexes.json" ]; then
  echo "Found mobile_app/firestore.indexes.json - Will be removed"
fi

if [ -f "mobile_app/.firebaserc" ]; then
  echo "Found mobile_app/.firebaserc - Will be removed"
fi

# Ask for confirmation
echo
echo "The files will be removed. Files in the root directory will be used instead."
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Remove files
if [ -f "mobile_app/firebase.json" ]; then
  rm "mobile_app/firebase.json"
  echo "Removed mobile_app/firebase.json"
fi

if [ -f "mobile_app/firestore.rules" ]; then
  rm "mobile_app/firestore.rules"
  echo "Removed mobile_app/firestore.rules"
fi

if [ -f "mobile_app/firestore.indexes.json" ]; then
  rm "mobile_app/firestore.indexes.json"
  echo "Removed mobile_app/firestore.indexes.json"
fi

if [ -f "mobile_app/.firebaserc" ]; then
  rm "mobile_app/.firebaserc"
  echo "Removed mobile_app/.firebaserc"
fi

echo
echo "Cleanup complete."
echo "Firebase configuration files in the root directory will now be used for deployment."
echo "To deploy all Firebase resources, run: firebase deploy"
echo 