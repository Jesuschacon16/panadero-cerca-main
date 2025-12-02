// lista_repartidores_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asignar_inventario_page.dart';

class ListaRepartidoresPage extends StatelessWidget {
  const ListaRepartidoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Repartidor')),
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
                title: Text(data['name'] ?? 'Sin nombre'),
                subtitle: Text(data['email'] ?? 'Sin correo'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => AsignarInventarioPage(
                            repartidorId: repartidor.id,
                            repartidorName:
                                data['name'] ?? 'Nombre no disponible',
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
