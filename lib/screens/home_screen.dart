import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HomeScreen extends StatelessWidget {
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref('posts');

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _postsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading...'));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('Tidak ada data'));
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          final posts = data.entries.toList();

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postKey = posts[index].key;
              final post = posts[index].value;

              return ListTile(
                title: Text(post['description'] ?? 'No description'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User: ${post['username']}'),
                    Text('Status: ${post['status']}'),
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
