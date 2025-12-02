import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificacionesClientePage extends StatelessWidget {
  const NotificacionesClientePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Notificaciones')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notificaciones')
                .doc(userId)
                .collection('mensajes')
                .orderBy('fecha', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final mensajes = snapshot.data!.docs;

          if (mensajes.isEmpty) {
            return const Center(child: Text('No tienes notificaciones'));
          }

          return ListView(
            children:
                mensajes.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(data['titulo'] ?? 'Sin título'),
                    subtitle: Text(data['descripcion'] ?? data['mensaje'] ?? ''),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
