
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/crud_service.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CrudService service = CrudService();
  final AuthService authService = AuthService();
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();

  bool favoritesOnly = false;

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  // ADD ITEM
  void openAddDialog() {
    nameCtrl.clear();
    qtyCtrl.clear();
    File? selectedImage;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedImage != null)
                  Image.file(selectedImage!, height: 100),
                TextButton.icon(
                  onPressed: saving ? null : () async {
                    final image = await service.pickImageForAddItem();
                    if (image != null && dialogContext.mounted) {
                      setDialogState(() => selectedImage = image);
                    }
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name = nameCtrl.text.trim();
                final quantity = int.tryParse(qtyCtrl.text.trim());

                if (name.isEmpty || quantity == null || quantity < 0) {
                  message('Enter a valid name and quantity.');
                  return;
                }

                setDialogState(() => saving = true);

                try {
                  String imageUrl = '';

                  if (selectedImage != null) {
                    imageUrl = await service.uploadImage(selectedImage!);
                  }

                  await service.addItem(
                    name,
                    quantity,
                    imageUrl: imageUrl,
                  );

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  message('Item added successfully!');
                } catch (e) {
                  message('Error adding item: $e');
                  if (dialogContext.mounted) {
                    setDialogState(() => saving = false);
                  }
                }
              },
              child: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // EDIT ITEM
  void openEditDialog(DocumentSnapshot item) {
    final data = item.data() as Map<String, dynamic>;
    nameCtrl.text = data['name']?.toString() ?? '';
    qtyCtrl.text = data['quantity']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text.trim());

              if (name.isEmpty || quantity == null || quantity < 0) {
                message('Enter a valid name and quantity.');
                return;
              }

              Navigator.pop(dialogContext);
              try {
                await service.updateItem(item.id, name, quantity);
                message('Item updated successfully!');
              } catch (e) {
                message('Error updating item: $e');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // DELETE ITEM
  void confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await service.deleteItem(id);
                message('Item deleted successfully!');
              } catch (e) {
                message('Error deleting item: $e');
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        title: const Text('Tacusalme, Renan Angelo'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(
              favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => favoritesOnly = !favoritesOnly);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authService.logout();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: openAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final filteredDocs = favoritesOnly
              ? docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isFavorite'] == true;
                }).toList()
              : docs;

          if (filteredDocs.isEmpty) {
            return Center(
              child: Text(
                favoritesOnly
                    ? 'No favorite items found'
                    : 'No items found',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final item = filteredDocs[index];
              final data = item.data() as Map<String, dynamic>;

              final name = data['name']?.toString() ?? 'Unnamed item';
              final quantity = data['quantity'] ?? 0;
              final imageUrl = data['image_url']?.toString() ?? '';
              final isFavorite = data['isFavorite'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.image, size: 40),
                  title: Text(name),
                  subtitle: Text('Quantity $quantity'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.pink,
                        ),
                        onPressed: () async {
                          await service.toggleFavorite(
                            item.id,
                            isFavorite,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                        ),
                        onPressed: () => openEditDialog(item),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () => confirmDelete(item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
