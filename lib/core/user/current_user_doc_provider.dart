import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Streams the signed-in user's Firestore document from `users/{uid}`.
///
/// IMPORTANT:
/// We must cancel the previous Firestore subscription when auth user changes
/// (logout -> login), otherwise old listeners can keep running and throw.
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final controller = StreamController<Map<String, dynamic>?>.broadcast();

  StreamSubscription<User?>? authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;

  void attachUser(User? user) {
    // Cancel any previous doc listener
    docSub?.cancel();
    docSub = null;

    // ignore: avoid_print
    print('[currentUserDocProvider] attachUser called with user: $user');

    if (user == null || user.isAnonymous) {
      // ignore: avoid_print
      print(
        '[currentUserDocProvider] User is null or anonymous, emitting null',
      );
      if (!controller.isClosed) {
        controller.add(null);
      }
      return;
    }

    // ignore: avoid_print
    print(
      '[currentUserDocProvider] Setting up Firestore listener for user: ${user.uid}',
    );

    docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) {
            // ignore: avoid_print
            print(
              '[currentUserDocProvider] Firestore snapshot received - exists: ${doc.exists}, data: ${doc.data()}',
            );
            if (!doc.exists) {
              // ignore: avoid_print
              print(
                '[currentUserDocProvider] Document does not exist, emitting null',
              );
              if (!controller.isClosed) {
                controller.add(null);
              }
              return;
            }
            // ignore: avoid_print
            print(
              '[currentUserDocProvider] Emitting user doc data: ${doc.data()}',
            );
            if (!controller.isClosed) {
              controller.add(doc.data());
            }
          },
          onError: (e) {
            // ignore: avoid_print
            print('[currentUserDocProvider] Firestore error: $e');
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );
  }

  // ignore: avoid_print
  print('[currentUserDocProvider] INITIALIZING');

  // Get current auth state immediately
  final authState = ref.watch(authStateProvider);
  authState.maybeWhen(
    data: (user) {
      // ignore: avoid_print
      print('[currentUserDocProvider] Initial auth state received: $user');
      if (!controller.isClosed) {
        attachUser(user);
      }
    },
    orElse: () {
      // ignore: avoid_print
      print('[currentUserDocProvider] Initial auth state not ready yet');
    },
  );

  // Also listen for auth state changes
  authSub = ref
      .watch(authStateProvider.stream)
      .listen(
        (user) {
          // ignore: avoid_print
          print('[currentUserDocProvider] Auth state changed: $user');
          if (!controller.isClosed) {
            attachUser(user);
          }
        },
        onError: (e) {
          // ignore: avoid_print
          print('[currentUserDocProvider] Auth state error: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        },
      );

  ref.onDispose(() async {
    // ignore: avoid_print
    print('[currentUserDocProvider] DISPOSING');
    await docSub?.cancel();
    await authSub?.cancel();
    await controller.close();
  });

  return controller.stream;
});
