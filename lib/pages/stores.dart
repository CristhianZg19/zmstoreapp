import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Stores extends StatefulWidget {
  @override
  _StoresState createState() => _StoresState();
}

class Products extends StatelessWidget {
  final String uid;
  final String tienda;

  Products({required this.uid, required this.tienda});
  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;

    return Scaffold(
        appBar: AppBar(
          title: Center(child: Text(tienda)),
          backgroundColor: Color.fromARGB(255, 3, 3, 3),
          elevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('images')
              .where('idUser', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final docs = snapshot.data?.docs;
              if (docs!.isEmpty) {
                return Center(
                  child: Text('No tiene productos'),
                );
              }
              return GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250, // ancho máximo de cada elemento
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 1,
                  ),
                  itemCount: docs != null ? docs.length : 0,
                  itemBuilder: (context, index) {
                    final document = docs![index];
                    final data = document.data() as Map<String, dynamic>;
                    final imageUrl = data['url'];
                    final userLiked =
                        data['likes'].contains(auth.currentUser?.uid ?? '');
                    final phoneNumber = data['phoneNumber'];
                    final nombreProd = data['nombreProd'];

                    return Card(
                      color: Color.fromARGB(255, 255, 255, 255),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(3),
                              child: Text(
                                nombreProd,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.left,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              color: Colors.grey[200],
                              height: 300,
                              padding: EdgeInsets.all(0),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: PhotoView(
                                  imageProvider:
                                      CachedNetworkImageProvider(imageUrl),
                                  minScale: PhotoViewComputedScale.contained,
                                  maxScale:
                                      PhotoViewComputedScale.covered * 1.3,
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
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  child: IconButton(
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Iniciar sesión para poder dar like'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        // User is not signed in. Show a snackbar or navigate to sign in screen.
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                SizedBox(
                                  child: IconButton(
                                    icon: Icon(Icons.phone),
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
                                                'Asegúrate de tener instalada la aplicación de WhatsApp.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  });
            } else if (snapshot.hasError) {
              return Text('Ocurrió un error al cargar los productos.');
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ));
  }
}

class _StoresState extends State<Stores> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Tiendas')),
        backgroundColor: Color.fromARGB(255, 3, 3, 3),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('tienda', isNotEqualTo: '')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final docs = snapshot.data?.docs;
            return GridView.builder(
              padding: EdgeInsets.all(10),
              itemCount: docs?.length ?? 0,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final data = docs?[index].data() as Map<String, dynamic>;
                final imageUrl = data['photoStore'];

                return Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => Products(
                              uid: data['uid'], tienda: data['tienda'])));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl, // url de la imagen
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          data['tienda'], // propiedad arriba de la imagen
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 5),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Text('Ocurrió un error al cargar las tiendas.');
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
