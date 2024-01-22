import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';

class LoginPage extends StatefulWidget {
  @override
  State createState() {
    return _LoginState();
  }
}

class UserC {
  final String email;
  final String uid;
  final String displayName;
  String phoneNumber;
  final Timestamp date;
  String tienda;
  String photoStore;

  UserC({
    required this.email,
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
    required this.date,
    required this.tienda,
    required this.photoStore,
  });

  UserC copyWith({String? photoStore}) {
    return UserC(
      email: this.email,
      uid: this.uid,
      displayName: this.displayName,
      phoneNumber: this.phoneNumber,
      date: this.date,
      tienda: this.tienda,
      photoStore: photoStore ?? this.photoStore,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserC? _userC;

  UserC? get userC => _userC;

  void setUserC(UserC? userC) {
    _userC = userC;
    notifyListeners();
  }
}

class _LoginState extends State<LoginPage> {
  late FirebaseAuth auth;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final picker = ImagePicker();
  final cropper = ImageCropper();
  bool _uploading = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _descripcionController = TextEditingController();
  TextEditingController _phoneNumberController = TextEditingController();
  TextEditingController _tiendaController = TextEditingController();

  List<DocumentSnapshot> _images = [];

  File _image = File('');
  late String _descripcion = '';
  late String _nameProducto = '';
  late String _phoneNumber = '';
  late String _tienda = '';
  User? _user;
  UserC? _userC;

  @override
  void initState() {
    auth = FirebaseAuth.instance;

    super.initState();
    _checkCurrentUser();

    firestore
        .collection('images')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _images = snapshot.docs;
      });
    });
  }

  void _checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _user = user;
      });

      // Guardar la información del usuario en la variable _userC
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      _userC = UserC(
        email: user.email ?? '',
        uid: user.uid,
        displayName: user.displayName ?? '',
        phoneNumber: userDoc.get('phoneNumber') ?? '',
        date: userDoc.get('date'),
        tienda: userDoc.get('tienda') ?? '',
        photoStore: userDoc.get('photoStore') ?? '',
      );
      setState(() {
        _userC = _userC;
      });
    }
  }

  Future<void> _updatePhoneNumber(String phoneNumber) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String uid = user.uid;
        CollectionReference usersRef =
            FirebaseFirestore.instance.collection('users');
        await usersRef.doc(uid).update({'phoneNumber': phoneNumber});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Se actualizo el número correctamente!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error updating phone number.'),
      ));
    }
    Navigator.pop(context);
  }

  Future<void> _updateTienda(TextEditingController controller) async {
    final newTienda = controller.text.trim();

    if (newTienda.length != 0) {
      // Update tienda field in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userC!.uid)
          .update({'tienda': newTienda});

      setState(() {
        _userC?.tienda = newTienda;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tienda actualizada')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La tienda no puede estar vacía')),
      );
    }

    Navigator.pop(context);
  }

  Future<void> updateImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = '${_user?.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child('images/$fileName');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: Stack(
              children: <Widget>[
                ModalBarrier(
                  dismissible: false,
                  color: Colors.black54,
                ),
                Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
          );
        },
      );
      final task = ref.putFile(file);
      final snapshot = await task.whenComplete(() {});
      final photoUrl = await snapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid) // Reemplaza 'uid' por el ID del usuario actual
          .update({'photoStore': photoUrl});

      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _userC!.photoStore = photoUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La imagen se actualizó correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<File?> cropImage(File imageFile) async {
    final croppedFile = await cropper.cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final croppedFile = await cropImage(File(pickedFile.path));
      if (croppedFile != null) {
        setState(() {
          _image = croppedFile;
        });
      }
    } else {
      print('No se seleccionó ninguna imagen.');
    }
  }

  void updatePhoneNumber(String _phoneNumber, String _tienda) async {
    // Obtener la referencia del documento a actualizar
    final document =
        FirebaseFirestore.instance.collection('users').doc(_user?.uid);
    // Actualizar los campos phoneNumber y tienda del documento
    await document.update({'phoneNumber': _phoneNumber, 'tienda': _tienda});
  }

  void _showUploadSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('La imagen se cargó correctamente.'),
        backgroundColor: Colors.green,
      ),
    );

    // Limpiar campos
    setState(() {
      _descripcion = '';
      _nameProducto = '';
    });
  }

  Future<void> uploadImage() async {
    if (_descripcion.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('La descripción debe contener como mínimo 10 caracteres.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_nameProducto.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'La nombre del producto debe contener como mínimo 5 caracteres.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_image == null || _image.path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debes seleccionar una imagen!.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _uploading = true; // Mostrar ProgressBar
    });

    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference firebaseStorageRef =
        FirebaseStorage.instance.ref().child('uploads/$fileName.jpg');
    UploadTask uploadTask = firebaseStorageRef.putFile(_image);
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    CollectionReference imagesRef =
        FirebaseFirestore.instance.collection('images');
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    DateTime now = DateTime.now();
    Timestamp timestamp = Timestamp.fromDate(now);
    imagesRef.add({
      'url': imageUrl,
      'nombreProd': _nameProducto,
      'descripcion': _descripcion,
      'idUser': uid,
      'fecha': timestamp,
      'likes': [],
      'phoneNumber': _phoneNumber
    });

    setState(() {
      _image = File('');
      _descripcion = '';
      _nameProducto = '';
      _nameController.clear();
      _descripcionController.clear();
      _uploading = false; // Ocultar ProgressBar
    });
    _showUploadSuccessSnackbar(); // Mostrar Snackbar
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // Verificar si ya existe un documento de usuario para el usuario actual en Firestore
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        // Si el documento existe, almacenar los datos del usuario en una variable global
        final userData = userDoc.data()!;
        setState(() {
          _userC = UserC(
              email: userData['email'],
              uid: userData['uid'],
              displayName: userData['displayName'],
              phoneNumber: userData['phoneNumber'],
              date: userData['date'],
              tienda: userData['tienda'],
              photoStore: userData['photoStore']);
        });
      } else {
        DateTime now = DateTime.now();
        Timestamp timestamp = Timestamp.fromDate(now);
        // Si el documento no existe, significa que este es el primer inicio de sesión del usuario
        // Guardar los datos del usuario en Firestore
        final userData = {
          'email': user.email,
          'uid': user.uid,
          'displayName': user.displayName,
          'phoneNumber': user.phoneNumber,
          'date': timestamp,
          'photoStore': user.photoURL
        };
        await userRef.set(userData);
      }

      setState(() {
        _user = user;
      });
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      setState(() {
        _user = null;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width;
    final double cellWidth = (maxWidth - 4) /
        2; // 4 es la suma del crossAxisSpacing de 2 y el padding de 2 en cada lado
    final double cellHeight = cellWidth;
    if (_user == null) {
      // scaffold para usuarios no logueados
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/login.png'), fit: BoxFit.cover),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <
              Widget>[
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // logo centrado
                      Image.asset(
                        'assets/logo.png',
                        height: 200,
                      ),
                      SizedBox(height: 50), // espacio entre el logo y el botón
                      ElevatedButton(
                        onPressed: _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          primary: Colors.white,
                          onPrimary: Colors.black,
                          padding: EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Image.asset(
                              'assets/google_logo.png',
                              height: 20,
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Iniciar sesión con Google',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 50), // espacio entre el botón y el texto
                      Text(
                        '©2022 Todos los derechos reservados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ]))
          ]),
        ),
      );
    } else {
      // scaffold para usuarios logueados

      return DefaultTabController(
        length: 2,
        child: _isLoading
            ? CircularProgressIndicator()
            : Scaffold(
                appBar: AppBar(
                  title: Center(child: Text('Bienvenido')),
                  backgroundColor: Color.fromARGB(255, 3, 3, 3),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  bottom: TabBar(
                    tabs: [
                      Tab(text: 'Perfil'),
                      Tab(text: 'Imágenes'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    // Contenido de la pestaña de perfil
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage:
                                    _user?.photoURL != null && _userC != null
                                        ? CachedNetworkImageProvider(
                                            _userC!.photoStore)
                                        : null,
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => updateImage(),
                                child: Text('Cambiar imagen'),
                              ),
                              SizedBox(height: 10),
                              _isLoading
                                  ? CircularProgressIndicator()
                                  : SizedBox(),
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: IconButton(
                                  onPressed: _signOut,
                                  icon: Icon(Icons.logout),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                _user!.displayName ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text('Actualizar número'),
                                        content: Form(
                                          key: _formKey,
                                          child: TextFormField(
                                            controller: _phoneNumberController,
                                            keyboardType: TextInputType.phone,
                                            decoration: InputDecoration(
                                              hintText: 'Ingrese su número',
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Por favor ingrese un número de teléfono';
                                              }
                                              if (value.length != 9) {
                                                return 'El número debe tener 9 dígitos';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                _updatePhoneNumber(
                                                    _phoneNumberController
                                                        .text);
                                              }
                                            },
                                            child: Text('Guardar'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Text(
                                  _userC?.phoneNumber ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text('Actualizar tienda'),
                                        content: Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextFormField(
                                                controller: _tiendaController,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Ingrese el nombre de su tienda',
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Por favor ingrese el nombre de su tienda';
                                                  }
                                                  if (value.length > 12) {
                                                    return 'El nombre de su tienda no puede ser mayor a 12 caracteres';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                _updateTienda(
                                                    _tiendaController);
                                              }
                                            },
                                            child: Text('Guardar'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Text(
                                  _userC?.tienda ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.black,
                          thickness: 1.0, // Grosor de la línea
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('images')
                                .where('idUser', isEqualTo: _user?.uid)
                                .orderBy('fecha',
                                    descending:
                                        true) // agrega el orderBy para ordenar por fecha
                                .snapshots(),
                            builder: (BuildContext context,
                                AsyncSnapshot<QuerySnapshot> snapshot) {
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }

                              if (!snapshot.hasData) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }
                              if (snapshot.data == null ||
                                  snapshot.data!.docs.isEmpty) {
                                return Text('No hay imágenes disponibles');
                              }

                              return GridView.builder(
                                padding: EdgeInsets.all(2),
                                itemCount: snapshot.data!.docs.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                  childAspectRatio: 1.0,
                                ),
                                itemBuilder: (BuildContext context, int index) {
                                  var doc = snapshot.data!.docs[index];
                                  return GestureDetector(
                                    onLongPress: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text('Eliminar imagen'),
                                            content: Text(
                                                '¿Está seguro que desea eliminar esta imagen?'),
                                            actions: <Widget>[
                                              TextButton(
                                                child: Text('Cancelar'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              TextButton(
                                                child: Text('Eliminar'),
                                                onPressed: () {
                                                  // Elimina la imagen de Firebase Storage
                                                  FirebaseStorage.instance
                                                      .refFromURL(doc['url'])
                                                      .delete();

                                                  // Elimina el registro de la imagen en Firestore
                                                  FirebaseFirestore.instance
                                                      .collection('images')
                                                      .doc(doc.id)
                                                      .delete();

                                                  Navigator.of(context).pop();

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'La imagen se eliminó'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl: doc['url'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) =>
                                          Icon(Icons.error),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    // Contenido de la pestaña de imágenes

                    SingleChildScrollView(
                      child: Container(
                        child: Column(
                          children: <Widget>[
                            SizedBox(height: 20.0),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('uid',
                                      isEqualTo: _user
                                          ?.uid) // agrega el orderBy para ordenar por fecha
                                  .snapshots(),
                              builder: (BuildContext context,
                                  AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (!snapshot.hasData) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.data!.docs.isNotEmpty &&
                                    snapshot.data!.docs[0]['phoneNumber'] !=
                                        null &&
                                    snapshot.data!.docs[0]['phoneNumber'] !=
                                        '') {
                                  return Column(
                                    //aqui quiero hacer una validacion de snapshot.data!.docs[0]['phoneNumber'] si es que es diferente de vacio o null mostrar lo de abajo de lo contrario mostrar un alertdialog para ingresar un numero de 9
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: InputDecoration(
                                          hintText: 'Nombre del Producto...',
                                          contentPadding: EdgeInsets.fromLTRB(
                                              20.0, 10.0, 20.0, 10.0),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _nameProducto = value;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 20.0),
                                      TextFormField(
                                        controller: _descripcionController,
                                        decoration: InputDecoration(
                                          hintText: 'Descripción...',
                                          contentPadding: EdgeInsets.fromLTRB(
                                              20.0, 10.0, 20.0, 10.0),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(32.0),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _descripcion = value;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 20.0),
                                      Container(
                                        height: 400,
                                        child: Center(
                                          child: Stack(
                                            children: [
                                              _image == null ||
                                                      _image.path == null ||
                                                      _image.path.isEmpty
                                                  ? Text(
                                                      'Seleccionar una imagen de tu galeria.')
                                                  : Image.file(_image),
                                              if (_uploading)
                                                Positioned.fill(
                                                  child: Container(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                                ),
                                              if (_image != null &&
                                                  _image.path != null &&
                                                  _image.path.isNotEmpty)
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: IconButton(
                                                    icon: Icon(Icons.clear),
                                                    onPressed: () {
                                                      setState(() {
                                                        _image = File('');
                                                      });
                                                    },
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20.0),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: <Widget>[
                                          FloatingActionButton(
                                            onPressed: getImage,
                                            tooltip: 'Seleccionar imagen',
                                            child: Icon(Icons.add_a_photo),
                                          ),
                                          FloatingActionButton(
                                            onPressed: uploadImage,
                                            tooltip: 'Subir imagen',
                                            child: Icon(Icons.cloud_upload),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                } else {
                                  return AlertDialog(
                                    title: Text(
                                      'Debes registrar un número para poder subir imagenes',
                                      style: TextStyle(fontSize: 20.0),
                                    ),
                                    content: Form(
                                      key: _formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFormField(
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: 'Número de teléfono',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(32.0),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _phoneNumber = value;
                                              });
                                            },
                                            validator: (value) {
                                              if (value!.length != 9) {
                                                return 'El número de teléfono debe tener 9 dígitos';
                                              }
                                              return null;
                                            },
                                          ),
                                          SizedBox(height: 16.0),
                                          TextFormField(
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Ingresar nombre de tu Tienda',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(32.0),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _tienda = value;
                                              });
                                            },
                                            validator: (value) {
                                              if (value!.isEmpty) {
                                                return 'Este campo no puede estar vacío';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        child: Text('Aceptar'),
                                        onPressed: () {
                                          if (_formKey.currentState!
                                                  .validate() &&
                                              _tienda.isNotEmpty) {
                                            updatePhoneNumber(
                                                _phoneNumber, _tienda);
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    }
  }
}
