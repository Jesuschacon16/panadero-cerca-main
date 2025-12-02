import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AsignarInventarioPage extends StatefulWidget {
  final String repartidorId;
  final String repartidorName;

  const AsignarInventarioPage({
    super.key,
    required this.repartidorId,
    required this.repartidorName,
  });

  @override
  State<AsignarInventarioPage> createState() => _AsignarInventarioPageState();
}

class _AsignarInventarioPageState extends State<AsignarInventarioPage> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  Future<void> _agregarProducto() async {
    final nombre = _nombreController.text.trim().toLowerCase();
    final cantidadStr = _cantidadController.text.trim();
    final precioStr = _precioController.text.trim();

    // Validación de formato del nombre
    final soloLetras = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!soloLetras.hasMatch(nombre)) {
      _mostrarMensaje("❌ El nombre solo debe contener letras.");
      return;
    }

    // Validación de cantidad
    if (!RegExp(r'^\d+$').hasMatch(cantidadStr)) {
      _mostrarMensaje("❌ La cantidad debe ser un número entero.");
      return;
    }

    // Validación de precio
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(precioStr)) {
      _mostrarMensaje("❌ El precio debe ser un número válido (ej. 5.50).");
      return;
    }

    final cantidad = int.parse(cantidadStr);
    final precio = double.parse(precioStr);

    if (nombre.isEmpty || cantidad <= 0 || precio <= 0) {
      _mostrarMensaje(
        "❌ Todos los campos son obligatorios y deben ser válidos.",
      );
      return;
    }

    // Validar si ya existe ese nombre
    final existe =
        await FirebaseFirestore.instance
            .collection('inventarios_repartidores')
            .doc(widget.repartidorId)
            .collection('productos')
            .where('nombre', isEqualTo: nombre)
            .get();

    if (existe.docs.isNotEmpty) {
      _mostrarMensaje("⚠️ Ya existe un producto con ese nombre.");
      return;
    }

    // Agregar producto
    await FirebaseFirestore.instance
        .collection('inventarios_repartidores')
        .doc(widget.repartidorId)
        .collection('productos')
        .add({'nombre': nombre, 'cantidad': cantidad, 'precio': precio});

    _nombreController.clear();
    _cantidadController.clear();
    _precioController.clear();
  }

  Future<void> _editarProducto(String id, Map<String, dynamic> data) async {
    _nombreController.text = data['nombre'];
    _cantidadController.text = data['cantidad'].toString();
    _precioController.text = data['precio'].toString();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Editar producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: _cantidadController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nuevoNombre =
                      _nombreController.text.trim().toLowerCase();
                  final nuevaCantidadStr = _cantidadController.text.trim();
                  final nuevoPrecioStr = _precioController.text.trim();

                  // Validaciones
                  final soloLetras = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
                  if (!soloLetras.hasMatch(nuevoNombre)) {
                    _mostrarMensaje("❌ El nombre solo debe tener letras.");
                    return;
                  }

                  if (!RegExp(r'^\d+$').hasMatch(nuevaCantidadStr)) {
                    _mostrarMensaje("❌ La cantidad debe ser un número entero.");
                    return;
                  }

                  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(nuevoPrecioStr)) {
                    _mostrarMensaje("❌ El precio debe ser un número válido.");
                    return;
                  }

                  final nuevaCantidad = int.parse(nuevaCantidadStr);
                  final nuevoPrecio = double.parse(nuevoPrecioStr);

                  if (nuevoNombre.isEmpty ||
                      nuevaCantidad <= 0 ||
                      nuevoPrecio <= 0) {
                    _mostrarMensaje(
                      "❌ Todos los campos son obligatorios y deben ser válidos.",
                    );
                    return;
                  }

                  // Verificar que no haya otro producto con ese mismo nombre
                  final existe =
                      await FirebaseFirestore.instance
                          .collection('inventarios_repartidores')
                          .doc(widget.repartidorId)
                          .collection('productos')
                          .where('nombre', isEqualTo: nuevoNombre)
                          .get();

                  final existeOtroConMismoNombre = existe.docs.any(
                    (doc) => doc.id != id,
                  );
                  if (existeOtroConMismoNombre) {
                    _mostrarMensaje(
                      "⚠️ Ya existe otro producto con ese nombre.",
                    );
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('inventarios_repartidores')
                      .doc(widget.repartidorId)
                      .collection('productos')
                      .doc(id)
                      .update({
                        'nombre': nuevoNombre,
                        'cantidad': nuevaCantidad,
                        'precio': nuevoPrecio,
                      });

                  _nombreController.clear();
                  _cantidadController.clear();
                  _precioController.clear();
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  Future<void> _eliminarProducto(String id) async {
    await FirebaseFirestore.instance
        .collection('inventarios_repartidores')
        .doc(widget.repartidorId)
        .collection('productos')
        .doc(id)
        .delete();
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventario de ${widget.repartidorName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                  ),
                ),
                TextField(
                  controller: _cantidadController,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _precioController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _agregarProducto,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('inventarios_repartidores')
                      .doc(widget.repartidorId)
                      .collection('productos')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final productos = snapshot.data!.docs;

                if (productos.isEmpty) {
                  return const Center(
                    child: Text('No hay productos asignados'),
                  );
                }

                return ListView.builder(
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final doc = productos[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['nombre']),
                      subtitle: Text(
                        'Cantidad: ${data['cantidad']}  Precio: \$${data['precio']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editarProducto(doc.id, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _eliminarProducto(doc.id),
                          ),
                        ],
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
}
