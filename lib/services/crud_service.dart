
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class CrudService {
  final CollectionReference items =
      FirebaseFirestore.instance.collection('items');

  final cloudinary = CloudinaryPublic(
    'ragk2jmx',
    'flutter_notes_preset',
    cache: false,
  );

  // PICK IMAGE
  Future<File?> pickImageForAddItem() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  // UPLOAD IMAGE
  Future<String> uploadImage(File file) async {
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  // CREATE
  Future<void> addItem(
    String name,
    int quantity, {
    String imageUrl = '',
  }) async {
    await items.add({
      'name': name,
      'quantity': quantity,
      'image_url': imageUrl,
      'isFavorite': false,
      'createdAt': Timestamp.now(),
    });
  }

  // READ
  Stream<QuerySnapshot> getItems() {
    return items
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // UPDATE
  Future<void> updateItem(
    String id,
    String name,
    int quantity,
  ) async {
    await items.doc(id).update({
      'name': name,
      'quantity': quantity,
    });
  }

  // FAVORITE
  Future<void> toggleFavorite(
    String id,
    bool isFavorite,
  ) async {
    await items.doc(id).update({
      'isFavorite': !isFavorite,
    });
  }

  // DELETE
  Future<void> deleteItem(String id) async {
    await items.doc(id).delete();
  }
}
