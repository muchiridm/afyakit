//lib/shared/utils/firestore_instance.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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
        SetOptions;

final db = FirebaseFirestore.instance;
