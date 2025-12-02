import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({
    super.key,
    required this.userRole,
    required this.userName,
    required this.userId,
    required this.repartidorId,
    required this.repartidorName,
  });

  final String userRole;
  final String userName;
  final String userId;
  final String repartidorId;
  final String repartidorName;

  @override
  _InventarioPageState createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  String? _selectedRepartidorId;
  List<Map<String, dynamic>> _repartidores = [];

  @override
  void initState() {
    super.initState();
    if (widget.userRole == 'admin') {
      _cargarRepartidores();
    }
  }

  Future<void> _cargarRepartidores() async {
    final query =
        await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'repartidor')
            .get();

    setState(() {
      _repartidores =
          query.docs.map((doc) {
            return {'id': doc.id, 'name': doc['name']};
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.userRole == 'admin'
              ? const Color(0xFFF3F3F3)
              : const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(
          widget.userRole == 'admin' ? 'Inventario' : 'Mi Inventario',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (widget.userRole == 'admin') ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: _selectedRepartidorId,
                hint: const Text('Selecciona un repartidor (opcional)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Inventario Global'),
                  ),
                  ..._repartidores.map((repartidor) {
                    return DropdownMenuItem<String>(
                      value: repartidor['id'],
                      child: Text(repartidor['name']),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRepartidorId = value;
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final productos = snapshot.data!.docs;

                if (productos.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron productos'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 10),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    final data = producto.data() as Map<String, dynamic>;

                    final nombre = data['nombre'] ?? 'Sin nombre';
                    final cantidad = data['cantidad'] ?? 0;
                    final precio = data['precio']?.toDouble() ?? 0.0;

                    return AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 500),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(
                            Icons.bakery_dining,
                            size: 40,
                            color: Colors.brown,
                          ),
                          title: Text(
                            nombre.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text(
                                'Cantidad disponible: $cantidad',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Precio: \$${precio.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildStream() {
    if (widget.userRole == 'admin') {
      if (_selectedRepartidorId == null) {
        return FirebaseFirestore.instance.collection('inventario').snapshots();
      } else {
        return FirebaseFirestore.instance
            .collection('inventarios_repartidores')
            .doc(_selectedRepartidorId)
            .collection('productos')
            .snapshots();
      }
    } else {
      return FirebaseFirestore.instance
          .collection('inventarios_repartidores')
          .doc(widget.repartidorId)
          .collection('productos')
          .snapshots();
    }
  }
}
