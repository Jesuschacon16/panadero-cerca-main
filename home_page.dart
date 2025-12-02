import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'inventario_page.dart';
import 'login_page.dart';
import 'pedido_details_page.dart';
import 'pedidos_page.dart';
import 'admin_repartidores_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.userName});
  final String userName;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _currentPosition;
  LatLng _centerLatLng = const LatLng(20.9635, -89.6273);
  String userName = "Cargando...";
  String userPhone = "Cargando...";
  String userRole = "repartidor";
  String userEmail = "Cargando...";
  String userId = '';
  bool isLoading = true;
  bool isActive = true;
  String? ultimoPedidoMostrado;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _uploadTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _requestNotificationPermissions();
    _monitorConnectivity();
  }

  void _monitorConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        _updateRepartidorActivo(false);
      } else {
        if (isActive) {
          _updateRepartidorActivo(true);
        }
      }
    });
  }

  Future<void> _initializeData() async {
    await _fetchUserInfo();
    await _startLocationUpdates();
    _startUploadTimer();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      var userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userData.exists && mounted) {
        setState(() {
          userName = userData['name'] ?? "Nombre no disponible";
          userPhone = userData['phone'] ?? "Número no disponible";
          userRole = userData['role'] ?? "repartidor";
          userEmail = user.email ?? "Correo no disponible";
        });
      }
    }
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _centerLatLng = LatLng(position.latitude, position.longitude);
      });
    });
  }

  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _uploadLocationToFirestore();
    });
  }

  Future<void> _uploadLocationToFirestore() async {
    if (_currentPosition == null ||
        userId.isEmpty ||
        userRole != 'repartidor' ||
        !isActive)
      return;
    await _updateRepartidorActivo(true);
  }

  Future<void> _updateRepartidorActivo(bool active) async {
    if (userId.isEmpty || _currentPosition == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('repartidores_activos')
        .doc(userId);

    if (!active) {
      await docRef.delete();
      return;
    }

    await docRef.set({
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'name': userName,
      'activo': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _requestNotificationPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  void _showUserInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Información del Usuario"),
            content: Text(
              "Nombre: $userName\nCorreo: $userEmail\nTeléfono: $userPhone\nRol: $userRole",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cerrar"),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _uploadTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _updateRepartidorActivo(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panadero Cerca'),
        actions: _buildAppBarActions(),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentPosition == null
              ? const Center(child: Text("Ubicación no disponible"))
              : FlutterMap(
                options: MapOptions(initialCenter: _centerLatLng, minZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('repartidores_activos')
                            .where('activo', isEqualTo: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      List<Marker> markers = [
                        Marker(
                          point: _centerLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ];

                      if (snapshot.hasData) {
                        final now = DateTime.now();
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final lat = data['lat'] ?? 0.0;
                          final lng = data['lng'] ?? 0.0;
                          final updatedAt =
                              (data['timestamp'] as Timestamp?)?.toDate();

                          if (updatedAt != null &&
                              now.difference(updatedAt).inSeconds < 30) {
                            markers.add(
                              Marker(
                                point: LatLng(lat, lng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            );
                          }
                        }
                      }

                      return MarkerLayer(markers: markers);
                    },
                  ),
                ],
              ),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('pedidos')
                    .where('repartidorId', isEqualTo: userId)
                    .where('estado', isEqualTo: 'pendiente')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final pedido = snapshot.data!.docs.first;
                final data = pedido.data() as Map<String, dynamic>;
                final pedidoId = pedido.id;
                final clienteId = data['clienteId'] ?? '';

                if (ultimoPedidoMostrado != pedidoId) {
                  ultimoPedidoMostrado = pedidoId;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        (ModalRoute.of(context)?.isCurrent ?? false)) {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('📦 Nuevo pedido recibido'),
                              content: Text(
                                'Cliente: ${data['clienteNombre'] ?? 'Cliente'}\n'
                                'Productos: ${(data['productos'] as List?)?.map((p) => p['nombre']).join(', ') ?? ''}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .doc(pedidoId)
                                        .update({'estado': 'en camino'});

                                    await FirebaseFirestore.instance
                                        .collection('notificaciones')
                                        .doc(clienteId)
                                        .collection('mensajes')
                                        .add({
                                          'titulo': '🚚 Pedido aceptado',
                                          'descripcion':
                                              'Tu pedido ha sido aceptado por el repartidor.',
                                          'fecha': FieldValue.serverTimestamp(),
                                          'leido': false,
                                      
                                        });
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => PedidoDetailsPage(
                                              pedidoId: pedidoId,
                                              clienteId: clienteId,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text('Aceptar Pedido'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancelar'),
                                ),
                              ],
                            ),
                      );
                    }
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.info_outline),
        onPressed: _showUserInfoDialog,
        tooltip: 'Información del usuario',
      ),
      IconButton(
        icon: const Icon(Icons.inventory),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => InventarioPage(
                    userRole: userRole,
                    userName: userName,
                    userId: userId,
                    repartidorId: userId,
                    repartidorName: userName,
                  ),
            ),
          );
        },
        tooltip: 'Inventario',
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () async {
          await _updateRepartidorActivo(false);
          await FirebaseAuth.instance.signOut();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        },
        tooltip: 'Cerrar sesión',
      ),
    ];

    if (userRole == 'repartidor') {
      actions.insert(
        0,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Activo', style: TextStyle(color: Colors.black)),
            const SizedBox(width: 4),
            Switch(
              value: isActive,
              onChanged: (value) {
                setState(() => isActive = value);
                _updateRepartidorActivo(value);
              },
              activeColor: Colors.white,
            ),
          ],
        ),
      );

      actions.insert(
        2,
        IconButton(
          icon: const Icon(Icons.list_alt),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PedidosPage(repartidorId: userId),
              ),
            );
          },
          tooltip: 'Ver mis pedidos',
        ),
      );
    }

    if (userRole == 'admin') {
      actions.insert(
        0,
        IconButton(
          icon: const Icon(Icons.assignment_turned_in_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminRepartidoresPage(),
              ),
            );
          },
          tooltip: 'Asignar Inventario',
        ),
      );
    }

    return actions;
  }
}
