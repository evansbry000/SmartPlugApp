import 'package:firebase_core/firebase_core.dart';

// Firebase configuration values
const firebaseConfig = {
  'apiKey': 'AIzaSyCDETZaO4KfbuahJuCrvupJgo4nFPvkA8E',
  'authDomain': 'smartplugdatabase-f1fd4.firebaseapp.com',
  'projectId': 'smartplugdatabase-f1fd4',
  'storageBucket': 'smartplugdatabase-f1fd4.firebasestorage.app',
  'messagingSenderId': '47673796402',
  'appId': '1:47673796402:web:df504c917c14f97e13d92b',
  'measurementId': 'G-FWL9MRFPQK',
};

// Firebase options instance for Flutter Web
final firebaseOptions = FirebaseOptions(
  apiKey: firebaseConfig['apiKey']!,
  appId: firebaseConfig['appId']!,
  messagingSenderId: firebaseConfig['messagingSenderId']!,
  projectId: firebaseConfig['projectId']!,
  authDomain: firebaseConfig['authDomain']!,
  storageBucket: firebaseConfig['storageBucket']!,
  measurementId: firebaseConfig['measurementId'],
); 