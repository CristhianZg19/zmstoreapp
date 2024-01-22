import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FirstPage extends StatefulWidget {
  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  late TextEditingController _searchController;
  String? _searchTerm;
  bool _isExpanded = false;
  Map<int, bool> expandedStates = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'ZM Store',
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _searchTerm = _searchController.text;
              });
            },
            icon: Icon(Icons.search),
          ),
          SizedBox(width: 16.0),
          Expanded(
            child: TypeAheadFormField<String>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _searchController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              suggestionsCallback: (String pattern) async {
                if (pattern.length >= 1) {
                  final queryUpper = pattern.toUpperCase();
                  final queryLow = pattern
                      .toLowerCase(); // Corregido: debe ser toLowerCase()
                  final snapshot = await db
                      .collection('images')
                      .where('nombreProd', isGreaterThanOrEqualTo: queryLow)
                      .where('nombreProd',
                          isLessThan: queryLow.substring(
                                  0, queryLow.length - 1) +
                              String.fromCharCode(
                                  queryLow.codeUnitAt(queryLow.length - 1) + 1))
                      .get();
                  final suggestions = snapshot.docs
                      .map((doc) => doc['nombreProd'] as String)
                      .where((word) =>
                          word.toUpperCase().startsWith(
                              queryUpper) || // Corregido: se convierte a mayúsculas antes de verificar
                          word.toLowerCase().startsWith(
                              queryLow)) // Corregido: se convierte a minúsculas antes de verificar
                      .toList();
                  return suggestions;
                } else {
                  return [];
                }
              },
              itemBuilder: (context, suggestion) => ListTile(
                title: Text(suggestion),
              ),
              onSuggestionSelected: (suggestion) {
                setState(() {
                  _searchTerm = suggestion;
                });
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _searchTerm != null && _searchTerm!.isNotEmpty
            ? db
                .collection('images')
                .where('nombreProd', isGreaterThanOrEqualTo: _searchTerm!)
                .where('nombreProd', isLessThan: _searchTerm! + 'Z')
                .orderBy('nombreProd', descending: true)
                .snapshots()
            : db
                .collection('images')
                .orderBy('fecha', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs;

          if (snapshot.data?.docs.isEmpty ?? true) {
            return Center(
              child: Text(
                'No se encontraron resultados',
                style: TextStyle(fontSize: 24),
              ),
            );
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              crossAxisSpacing: 5,
              mainAxisSpacing: 1,
            ),
            itemCount: docs != null ? docs.length : 0,
            itemBuilder: (context, index) {
              final document = docs![index];
              final imageUrl = document['url'];
              final description = document['descripcion'];
              final userLiked =
                  document['likes'].contains(auth.currentUser?.uid ?? '');
              final phoneNumber = document['phoneNumber'];
              final nombreProd = document['nombreProd'];
              final precio = document['precio'];

              bool _isExpanded = expandedStates[index] ?? false;

              return SingleChildScrollView(
                child: Card(
                  color: Color.fromARGB(255, 255, 255, 255),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                nombreProd,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.left,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      expandedStates[index] = !_isExpanded;
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 14,
                                        ),
                                        maxLines: _isExpanded ? 7 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: 300,
                        color: Colors.grey[200],
                        padding: EdgeInsets.all(0),
                        child: Column(
                          children: [
                            Expanded(
                              child: PhotoView(
                                imageProvider:
                                    CachedNetworkImageProvider(imageUrl),
                                minScale: PhotoViewComputedScale.contained,
                                maxScale: PhotoViewComputedScale.covered * 1.3,
                                backgroundDecoration:
                                    BoxDecoration(color: Colors.black),
                                heroAttributes:
                                    PhotoViewHeroAttributes(tag: 'hero'),
                                enableRotation: true,
                                loadingBuilder: (context, event) => Center(
                                  child: CircularProgressIndicator(
                                    value: event == null
                                        ? 0
                                        : event.cumulativeBytesLoaded /
                                            event.expectedTotalBytes!,
                                  ),
                                ),
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Icon(Icons.error),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      userLiked && auth.currentUser != null
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color:
                                          userLiked && auth.currentUser != null
                                              ? Colors.red
                                              : Colors.black,
                                    ),
                                    onPressed: () async {
                                      final user = auth.currentUser;
                                      if (user != null) {
                                        final likeRef = db
                                            .collection('images')
                                            .doc(document.id);
                                        if (userLiked) {
                                          await likeRef.update({
                                            'likes': FieldValue.arrayRemove(
                                                [user.uid])
                                          });
                                        } else {
                                          await likeRef.update({
                                            'likes': FieldValue.arrayUnion(
                                                [user.uid])
                                          });
                                        }
                                      } else {
                                        // User is not signed in. Show a snackbar or navigate to sign in screen.
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Iniciar sesión para poder dar like'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  SizedBox(width: 16),
                                  IconButton(
                                    icon: FaIcon(FontAwesomeIcons.whatsapp),
                                    onPressed: () async {
                                      String message =
                                          "Hola,%20estoy%20interesad@%20en%20el%20$nombreProd";
                                      String link =
                                          "whatsapp://send?phone=+51$phoneNumber&text=$message";

                                      Uri url = Uri.parse(link);

                                      print(link);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Iniciar sesión para poder dar like'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      'S/ $precio', // Aquí puedes cambiar el formato del precio
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
