import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'pedido_details_page.dart'; // Asegúrate de importar la página de detalles

class PedidosPage extends StatefulWidget {
  const PedidosPage({Key? key, required String repartidorId}) : super(key: key);

  @override
  _PedidosPageState createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _repartidorId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _repartidorId = _auth.currentUser?.uid ?? '';
    _verifyRepartidorId(); // Nueva función de verificación
  }

  Future<void> _verifyRepartidorId() async {
    print('ID del repartidor actual: $_repartidorId');

    // Verifica si el usuario existe en la colección correcta
    final userDoc =
        await _firestore.collection('users').doc(_repartidorId).get();

    if (!userDoc.exists) {
      print('ERROR: No se encontró el usuario en la colección users');
      return;
    }

    print('Usuario encontrado. Datos: ${userDoc.data()}');

    // Verifica pedidos asignados (consulta más flexible)
    final pedidosSnapshot =
        await _firestore
            .collection('pedidos')
            .where('repartidorId', isEqualTo: _repartidorId)
            .get();

    print('Pedidos encontrados: ${pedidosSnapshot.docs.length}');
    pedidosSnapshot.docs.forEach((doc) {
      print('Pedido ID: ${doc.id} - Datos: ${doc.data()}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('pedidos')
                .where('repartidorId', isEqualTo: _repartidorId)
                .orderBy('fecha', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          // Debug
          print('Estado de la consulta: ${snapshot.connectionState}');
          if (snapshot.hasError) {
            print('Error en la consulta: ${snapshot.error}');
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWidget();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyWidget();
          }

          return _buildPedidosList(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 20),
          const Text('Error al cargar pedidos', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Cargando pedidos...'),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_late, size: 50, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No tienes pedidos asignados',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            'ID del repartidor: $_repartidorId',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _verifyRepartidorId,
            child: const Text('Verificar datos en Firestore'),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final pedido = docs[index];
        final data = pedido.data() as Map<String, dynamic>;

        // Manejo seguro de campos
        final estado = data['estado']?.toString() ?? 'desconocido';
        final productos = data['productos'] is List ? data['productos'] : [];
        final fecha =
            data['fecha'] is Timestamp
                ? (data['fecha'] as Timestamp).toDate()
                : DateTime.now();

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('Pedido #${pedido.id.substring(0, 8)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado: ${estado.toUpperCase()}'),
                Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
                Text('Productos: ${_formatProductos(productos)}'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PedidoDetailsPage(
                        pedidoId: pedido.id,
                        clienteId: data['clienteId'] ?? '',
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatProductos(List<dynamic> productos) {
    if (productos.isEmpty) return 'Sin productos especificados';

    return productos
        .map((p) {
          if (p is Map<String, dynamic>) {
            return p['nombre']?.toString() ?? 'Producto sin nombre';
          }
          return 'Producto no válido';
        })
        .join(', ');
  }
}
