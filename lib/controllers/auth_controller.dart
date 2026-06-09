import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

class AuthController {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _uuid = Uuid();

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> sendEmailVerificationLink(String email) async {
    try {
      final tempPassword = 'Temp#${DateTime.now().millisecondsSinceEpoch}';
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: tempPassword);

      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.sendEmailVerification();
        return tempPassword;
      }
      throw Exception('Gagal membuat akun sementara Firebase');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email sudah terdaftar. Silakan gunakan email lain atau Login.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Format email tidak valid.');
      }
      throw Exception(e.message ?? 'Terjadi kesalahan saat verifikasi.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> isEmailVerified(String email, String tempPassword) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: tempPassword);
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.reload();
        return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<UserModel?> finalizeRegistration({
    required String namaLengkap,
    required String email,
    required String tempPassword,
    required String realPassword,
    String? noHp,
    DateTime? tanggalLahir,
    String? jenisKelamin,
  }) async {
    try {
      // 1. Sign in with temp password
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: tempPassword);

      final User? firebaseUser = userCredential.user;
      
      if (firebaseUser != null) {
        if (!firebaseUser.emailVerified) {
          throw Exception('Email belum diverifikasi');
        }

        // 2. Update to real password
        await firebaseUser.updatePassword(realPassword);

        // 3. Save to SQLite using Firebase UID
        final user = UserModel(
          userId: firebaseUser.uid,
          namaLengkap: namaLengkap,
          email: email,
          passwordHash: hashPassword(realPassword), // still hash for local reference
          noHp: noHp,
          tanggalLahir: tanggalLahir,
          jenisKelamin: jenisKelamin,
          batasBudget: 1600000, // Default budget
        );

        await _db.insertUser(user);
        return user;
      }
      throw Exception('Gagal menyelesaikan pembuatan akun');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserModel?> login(String email, String password) async {
    try {
      // 1. Sign in with Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Check if email is verified
        if (!firebaseUser.emailVerified) {
          throw Exception('unverified_email');
        }

        // 2. Get user from local DB using UID or Email
        UserModel? user = await _db.getUserByEmail(email);
        
        // If not found in local DB, it means they might be logging in from a new device!
        // We will return a temporary UserModel just to pass the UI logic,
        // The UserProvider will handle the CloudSyncRestore and re-fetch!
        if (user == null) {
          user = UserModel(
            userId: firebaseUser.uid,
            namaLengkap: firebaseUser.displayName ?? 'Pengguna',
            email: email,
            passwordHash: '',
            batasBudget: 1600000,
          );
        }

        return user;
      }
      throw Exception('Gagal masuk.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        throw Exception('Email belum terdaftar atau salah.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Sandi salah.');
      }
      throw Exception(e.message ?? 'Terjadi kesalahan saat masuk.');
    } catch (e) {
      if (e.toString() == 'Exception: unverified_email') {
        rethrow;
      }
      throw Exception(e.toString());
    }
  }

  Future<UserModel?> loginWithGoogle() async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
    if (googleUser == null) {
      return null; // The user canceled the sign-in
    }

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await auth.signInWithCredential(credential);
    final User? firebaseUser = userCredential.user;

    if (firebaseUser != null) {
      // Check if user already exists in local DB
      UserModel? user = await _db.getUserByEmail(firebaseUser.email ?? '');
      
      if (user == null) {
        // Create new user in local DB
        user = UserModel(
          userId: firebaseUser.uid, // Using Firebase UID
          namaLengkap: firebaseUser.displayName ?? 'Pengguna',
          email: firebaseUser.email ?? '',
          passwordHash: '', // No password for Google Sign In
          fotoProfil: firebaseUser.photoURL,
          batasBudget: 1600000,
        );
        await _db.insertUser(user);
      } else {
        // Update existing user with Google info if needed
        // For example, keeping the photo URL synced
        final updatedUser = UserModel(
          userId: user.userId,
          namaLengkap: firebaseUser.displayName ?? user.namaLengkap,
          email: user.email,
          passwordHash: user.passwordHash,
          fotoProfil: firebaseUser.photoURL ?? user.fotoProfil,
          batasBudget: user.batasBudget,
        );
        // We might need to update the user in DB, but since we don't have an updateUser method readily available here,
        // we'll just return the fetched user for now, or update it if updateProfile is called later.
        user = updatedUser;
      }
      return user;
    }
    return null;
  }
}
