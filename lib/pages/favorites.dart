import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zmstoreapp/pages/account.dart';

class SecondPage extends StatelessWidget {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
            title: Center(child: Text('Favoritos')),
            backgroundColor: Color.fromARGB(255, 3, 3, 3),
            elevation: 0,
           
          ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('images')
            .where('likes', arrayContains: auth.currentUser?.uid ?? '')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs;

          if (docs?.isEmpty ?? true) {
            return Center(
              child: Text(
                'No hay imágenes favoritas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return auth.currentUser == null
              ? Center(
                  child: Text(
                    'Debe iniciar sesión para poder ver el apartado de favoritos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 1,
                  ),
                  itemCount: docs?.length ?? 0,
                  itemBuilder: (context, index) {
                    final document = docs![index];
                    final imageUrl = document['url'];
                    final description = document['descripcion'];
                    final userLiked =
                        document['likes'].contains(auth.currentUser?.uid ?? '');

                    return Card(
                      color: Color.fromARGB(255, 255, 255, 255),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                description,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.left,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
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
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
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
                                          color: userLiked &&
                                                  auth.currentUser != null
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
                                          }
                                        },
                                      ),
                                      SizedBox(width: 16),
                                      IconButton(
                                        icon: Icon(Icons.phone),
                                        onPressed: () {
                                          // Acción al presionar el botón de Whatsapp
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
