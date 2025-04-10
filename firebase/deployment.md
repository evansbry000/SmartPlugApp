# Smart Plug App - Firebase Deployment Plan

This document outlines the step-by-step process for deploying the Firebase Cloud Functions for the Smart Plug App, which handle data mirroring between Realtime Database and Firestore.

## Prerequisites

1. **Firebase CLI**
   - Install the Firebase CLI: `npm install -g firebase-tools`
   - Log in to Firebase: `firebase login`

2. **Project Setup**
   - Ensure you have a Firebase project created with both Realtime Database and Firestore enabled
   - Verify billing is enabled (Cloud Functions require a billing account)

## Deployment Steps

### 1. Initialize Firebase (First Time Only)

If you haven't already initialized Firebase in your project:

```bash
cd SmartPlugApp
firebase init
```

Select the following options:
- Select your project
- Choose "Functions" 
- Use JavaScript
- Yes to ESLint
- Yes to install dependencies

### 2. Install Dependencies

```bash
cd firebase/functions
npm install
```

### 3. Configure Firebase Project

Make sure your Firebase project has:
- The correct database URLs
- Authentication methods enabled (Anonymous auth)
- Proper security rules for both Firestore and RTDB

### 4. Deploy Functions

```bash
firebase deploy --only functions
```

This will deploy all four functions:
- `mirrorCurrentData` - Mirrors device status from RTDB to Firestore
- `recordHistoricalData` - Records historical data every 2 minutes
- `mirrorEvents` - Mirrors events from RTDB to Firestore
- `cleanupHistoricalData` - Cleans up old data

### 5. Verify Deployment

After deployment, verify that the functions are running correctly:

1. Go to the Firebase console
2. Navigate to "Functions" 
3. Check that all functions are deployed successfully
4. Review logs for any errors

### 6. Testing the Functions

Test each function to ensure it's working properly:

1. **mirrorCurrentData**:
   - Update a device status in the Realtime Database
   - Verify the change is reflected in Firestore

2. **recordHistoricalData**:
   - Wait for the scheduled function to run (every 2 minutes)
   - Check that historical data is recorded in Firestore

3. **mirrorEvents**:
   - Create an event in the Realtime Database
   - Verify the event is mirrored to Firestore

4. **cleanupHistoricalData**:
   - This runs on a daily schedule, but you can trigger it manually for testing
   - Verify that old data is removed according to the retention policy

### 7. Monitoring

Set up monitoring for your functions:

1. Go to the Firebase console > Functions > Logs
2. Set up alerts for function failures
3. Monitor performance and execution counts

## Troubleshooting

If you encounter issues:

1. Check function logs in the Firebase console
2. Verify permissions and security rules
3. Ensure your Firebase plan supports the function execution frequency
4. Check if you've exceeded your function execution quota

## Updating Functions

To update functions after making changes:

```bash
firebase deploy --only functions
```

Or deploy a specific function:

```bash
firebase deploy --only functions:mirrorCurrentData
``` 