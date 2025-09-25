import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

export 'package:cloud_firestore/cloud_firestore.dart'
    show
        FirebaseFirestore,
        FieldPath,
        DocumentReference,
        CollectionReference,
        QuerySnapshot,
        DocumentSnapshot,
        QueryDocumentSnapshot,
        Timestamp,
        FieldValue,
        WriteBatch,
        SetOptions,
        GetOptions,
        Source,
        FirebaseException,
        Settings,
        Query;

final db = FirebaseFirestore.instance;

/// MUST match your backend setGlobalOptions({ region: 'europe-west1' })
const kFunctionsRegion = 'europe-west1';

final functions = FirebaseFunctions.instanceFor(
  app: Firebase.app(),
  region: kFunctionsRegion,
);

/// Optional convenience (cuts boilerplate)
HttpsCallable callable(String name) => functions.httpsCallable(name);
