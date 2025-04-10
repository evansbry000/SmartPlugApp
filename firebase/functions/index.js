const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Reference to both databases
const rtdb = admin.database();
const firestore = admin.firestore();

/**
 * Function to mirror device status data from RTDB to Firestore
 * This function is triggered whenever the device status changes in RTDB
 */
exports.mirrorCurrentData = functions.database
  .ref('/devices/{deviceId}/status')
  .onWrite(async (change, context) => {
    const deviceId = context.params.deviceId;
    console.log(`Status update for device: ${deviceId}`);

    // If data was deleted, ignore
    if (!change.after.exists()) {
      console.log('Data was deleted, ignoring');
      return null;
    }

    // Get the data after the change
    const data = change.after.val();

    // Add timestamp if not present
    if (!data.timestamp) {
      data.timestamp = admin.firestore.FieldValue.serverTimestamp();
    } else {
      // Convert RTDB timestamp to Firestore timestamp
      data.timestamp = new Date(data.timestamp);
    }

    // Check if emergencyStatus is present, if not add it
    if (data.emergencyStatus === undefined) {
      data.emergencyStatus = false;
    }

    // Check if we need to record this as an emergency in Firestore
    if (data.emergencyStatus) {
      await firestore.collection('smart_plugs').doc(deviceId)
        .collection('events').add({
          type: 'emergency',
          message: 'HIGH_TEMPERATURE',
          temperature: data.temperature,
          timestamp: data.timestamp || admin.firestore.FieldValue.serverTimestamp()
        });
      console.log(`Emergency event recorded for device: ${deviceId}`);
    }

    // Update the current data in Firestore
    return firestore.collection('smart_plugs').doc(deviceId).update(data)
      .then(() => {
        console.log(`Status successfully mirrored for device: ${deviceId}`);
        return null;
      })
      .catch(error => {
        console.error(`Error mirroring status for device: ${deviceId}`, error);
        return null;
      });
  });

/**
 * Function to record historical data in Firestore every 2 minutes
 * This function is triggered by a scheduled job
 */
exports.recordHistoricalData = functions.pubsub
  .schedule('every 2 minutes')
  .onRun(async () => {
    console.log('Starting scheduled historical data recording');

    try {
      // Get all devices from RTDB
      const devicesSnapshot = await rtdb.ref('/devices').once('value');
      const devices = devicesSnapshot.val();

      if (!devices) {
        console.log('No devices found');
        return null;
      }

      // For each device, record the current status to its history collection
      const promises = Object.keys(devices).map(async deviceId => {
        const statusData = devices[deviceId].status;
        
        if (!statusData) {
          console.log(`No status data for device: ${deviceId}`);
          return null;
        }

        // Add timestamp if not present
        if (!statusData.timestamp) {
          statusData.timestamp = admin.firestore.FieldValue.serverTimestamp();
        } else {
          // Convert RTDB timestamp to Firestore timestamp
          statusData.timestamp = new Date(statusData.timestamp);
        }

        // Record to Firestore
        return firestore.collection('smart_plugs').doc(deviceId)
          .collection('history').add(statusData)
          .then(() => {
            console.log(`Historical data recorded for device: ${deviceId}`);
            return null;
          })
          .catch(error => {
            console.error(`Error recording historical data for device: ${deviceId}`, error);
            return null;
          });
      });

      await Promise.all(promises);
      console.log('Historical data recording completed');
      return null;
    } catch (error) {
      console.error('Error in historical data recording:', error);
      return null;
    }
  });

/**
 * Function to mirror events data from RTDB to Firestore
 * This function is triggered whenever a new event is added to RTDB
 */
exports.mirrorEvents = functions.database
  .ref('/events/{eventId}')
  .onCreate(async (snapshot, context) => {
    const eventId = context.params.eventId;
    console.log(`New event: ${eventId}`);

    // Get the event data
    const eventData = snapshot.val();
    if (!eventData) {
      console.log('No event data found');
      return null;
    }

    // Extract device ID from event ID if it follows the pattern {deviceId}_*
    let deviceId = 'plug1'; // Default device ID
    if (eventId.includes('_')) {
      deviceId = eventId.split('_')[0];
    }

    // Add timestamp if not present
    if (!eventData.timestamp) {
      eventData.timestamp = admin.firestore.FieldValue.serverTimestamp();
    } else {
      // Convert RTDB timestamp to Firestore timestamp
      eventData.timestamp = new Date(eventData.timestamp);
    }

    // Record to Firestore
    return firestore.collection('smart_plugs').doc(deviceId)
      .collection('events').add(eventData)
      .then(() => {
        console.log(`Event mirrored to Firestore for device: ${deviceId}`);
        return null;
      })
      .catch(error => {
        console.error(`Error mirroring event for device: ${deviceId}`, error);
        return null;
      });
  });

/**
 * Function to clean up old historical data (older than 7 days)
 * This function is triggered once a day
 */
exports.cleanupHistoricalData = functions.pubsub
  .schedule('every day 00:00')
  .onRun(async () => {
    console.log('Starting daily cleanup of historical data');

    try {
      // Calculate cutoff date (7 days ago)
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 7);

      // Get all smart plug documents
      const smartPlugsSnapshot = await firestore.collection('smart_plugs').get();
      
      // For each smart plug, delete old historical data
      const promises = smartPlugsSnapshot.docs.map(async plugDoc => {
        const deviceId = plugDoc.id;
        
        // Query for historical data older than the cutoff date
        const oldDataQuery = firestore.collection('smart_plugs').doc(deviceId)
          .collection('history')
          .where('timestamp', '<', cutoffDate)
          .limit(500); // Process in batches to avoid timeout
          
        // Delete the old data
        return deleteQueryBatch(firestore, oldDataQuery);
      });

      await Promise.all(promises);
      console.log('Historical data cleanup completed');
      return null;
    } catch (error) {
      console.error('Error in historical data cleanup:', error);
      return null;
    }
  });

/**
 * Helper function to delete documents in batches
 */
async function deleteQueryBatch(db, query) {
  while (true) {
    const snapshot = await query.get();
    
    // When there are no documents left, we are done
    if (snapshot.size === 0) {
      return 0;
    }
    
    // Delete documents in a batch
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    
    // Count of deleted documents
    return snapshot.size;
  }
} 