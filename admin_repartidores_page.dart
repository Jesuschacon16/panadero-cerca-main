import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asignar_inventario_page.dart';

class AdminRepartidoresPage extends StatelessWidget {
  const AdminRepartidoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Repartidores')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'repartidor')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final repartidores = snapshot.data!.docs;

          if (repartidores.isEmpty) {
            return const Center(child: Text('No hay repartidores registrados'));
          }

          return ListView.builder(
            itemCount: repartidores.length,
            itemBuilder: (context, index) {
              final repartidor = repartidores[index];
              final data = repartidor.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? 'Sin nombre'),
                subtitle: Text(data['email'] ?? 'Sin correo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => AsignarInventarioPage(
                            repartidorId: repartidor.id,
                            repartidorName: data['name'] ?? 'Repartidor',
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
