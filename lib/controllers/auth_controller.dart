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

  Future<UserModel?> register({
    required String namaLengkap,
    required String email,
    required String password,
    String? noHp,
    DateTime? tanggalLahir,
    String? jenisKelamin,
  }) async {
    // Check if email already exists
    final existing = await _db.getUserByEmail(email);
    if (existing != null) {
      throw Exception('Email sudah terdaftar');
    }

    final user = UserModel(
      userId: _uuid.v4(),
      namaLengkap: namaLengkap,
      email: email,
      passwordHash: hashPassword(password),
      noHp: noHp,
      tanggalLahir: tanggalLahir,
      jenisKelamin: jenisKelamin,
      batasBudget: 1600000, // Default budget
    );

    await _db.insertUser(user);
    return user;
  }

  Future<UserModel?> login(String email, String password) async {
    final user = await _db.getUserByEmail(email);
    if (user == null) {
      throw Exception('Email tidak ditemukan');
    }

    final passwordHash = hashPassword(password);
    if (user.passwordHash != passwordHash) {
      throw Exception('Password salah');
    }

    return user;
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
