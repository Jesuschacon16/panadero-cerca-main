import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PedidoDetailsPage extends StatefulWidget {
  final String pedidoId;
  final String clienteId;

  const PedidoDetailsPage({
    super.key,
    required this.pedidoId,
    required this.clienteId,
  });

  @override
  State<PedidoDetailsPage> createState() => _PedidoDetailsPageState();
}

class _PedidoDetailsPageState extends State<PedidoDetailsPage> {
  Map<String, dynamic>? pedidoData;
  LatLng? clienteLatLng;
  LatLng? repartidorLatLng;

  @override
  void initState() {
    super.initState();
    _cargarPedido();
    _escucharUbicacionCliente();
    _obtenerUbicacionRepartidor();
  }

  Future<void> _cargarPedido() async {
    final pedidoSnapshot =
        await FirebaseFirestore.instance
            .collection('pedidos')
            .doc(widget.pedidoId)
            .get();
    if (pedidoSnapshot.exists) {
      setState(() {
        pedidoData = pedidoSnapshot.data();
      });
    }
  }

  void _escucharUbicacionCliente() {
    FirebaseFirestore.instance
        .collection('clientes_activos')
        .doc(widget.clienteId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final lat = data['lat'] ?? 0.0;
            final lng = data['lng'] ?? 0.0;
            setState(() {
              clienteLatLng = LatLng(lat, lng);
            });
          }
        });
  }

  Future<void> _obtenerUbicacionRepartidor() async {
    final posicion =
        await FirebaseFirestore.instance
            .collection('repartidores_activos')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();
    if (posicion.exists) {
      final data = posicion.data()!;
      final lat = data['lat'];
      final lng = data['lng'];
      setState(() {
        repartidorLatLng = LatLng(lat, lng);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pedidoData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final productos = pedidoData?['productos'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del Pedido')),
      body: Column(
        children: [
          Expanded(
            child:
                clienteLatLng == null
                    ? const Center(
                      child: Text('Esperando ubicación del cliente...'),
                    )
                    : FlutterMap(
                      options: MapOptions(
                        initialCenter: clienteLatLng!,
                        minZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            if (clienteLatLng != null)
                              Marker(
                                point: clienteLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            if (repartidorLatLng != null)
                              Marker(
                                point: repartidorLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.green,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...productos.map((producto) {
                  return Text(
                    '• ${producto['nombre']} x${producto['cantidad']}',
                    style: const TextStyle(fontSize: 16),
                  );
                }).toList(),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _confirmarEntrega,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Marcar como Entregado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEntrega() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar entrega'),
            content: const Text(
              '¿Estás seguro que quieres marcar este pedido como entregado?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      final pedidoRef = FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId);
      final pedidoSnapshot = await pedidoRef.get();

      if (pedidoSnapshot.exists) {
        final pedidoData = pedidoSnapshot.data()!;
        final productos = List<Map<String, dynamic>>.from(
          pedidoData['productos'],
        );
        final repartidorId = FirebaseAuth.instance.currentUser!.uid;

        final inventarioRef = FirebaseFirestore.instance
            .collection('inventarios_repartidores')
            .doc(repartidorId)
            .collection('productos');

        for (final producto in productos) {
          final nombre = producto['nombre'];
          final cantidadVendida = producto['cantidad'] ?? 1;

          final query =
              await inventarioRef
                  .where('nombre', isEqualTo: nombre)
                  .limit(1)
                  .get();

          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            final stockActual = (doc['cantidad'] ?? 0) as int;
            await inventarioRef.doc(doc.id).update({
              'cantidad': stockActual - cantidadVendida,
            });
          }
        }

        // Cambiar estado del pedido
        await pedidoRef.update({'estado': 'entregado'});

        // Enviar notificación al cliente
        await FirebaseFirestore.instance
            .collection('notificaciones')
            .doc(widget.clienteId)
            .collection('mensajes')
            .add({
              'titulo': '✅ Pedido entregado',
              'descripcion': 'Tu pedido ha sido entregado por el repartidor.',
              'fecha': FieldValue.serverTimestamp(),
              'leido': false,
            });
      }

      if (mounted) Navigator.pop(context);
    }
  }
}
