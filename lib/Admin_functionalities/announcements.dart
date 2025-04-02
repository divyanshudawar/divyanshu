import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class Announcements extends StatefulWidget {
  const Announcements({super.key});

  @override
  State<Announcements> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<Announcements> {
  DocumentSnapshot? announcements;
  bool isLoading = true;

  Future<void> initialize() async {
    announcements = await FirebaseFirestore.instance
        .collection("Announcements")
        .doc("Announcements")
        .get();
    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> _handleRefresh() async {
    setState(() => isLoading = true);
    await initialize();
  }

  Future<void> _addAnnouncement() async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Announcement"),
        content: TextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.isNotEmpty) {
                final doc = FirebaseFirestore.instance
                    .collection("Announcements")
                    .doc("Announcements");

                await doc.update({
                  "Announcements": FieldValue.arrayUnion([textController.text])
                });
                Navigator.pop(context);
                await _handleRefresh();
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(int index) async {
    final doc = FirebaseFirestore.instance
        .collection("Announcements")
        .doc("Announcements");

    final List currentList = List.from(announcements?['Announcements'] ?? []);
    if (index >= 0 && index < currentList.length) {
      // Calculate original index accounting for reversed display
      int originalIndex = currentList.length - 1 - index;
      currentList.removeAt(originalIndex);
      await doc.update({"Announcements": currentList});
      await _handleRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List announcementList = List.from(
        (announcements?.get('Announcements') as List? ?? []).reversed);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Announcements",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: announcementList.isEmpty
                        ? Center(
                            child: Text("No Annoucements Yet"),
                          )
                        : ListView.builder(
                            itemCount: announcementList.length,
                            itemBuilder: (context, index) {
                              return Dismissible(
                                key: Key(announcementList[index]),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  color: Colors.red[800],
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 20.0),
                                    child:
                                        Icon(Icons.delete, color: Colors.white),
                                  ),
                                ),
                                onDismissed: (direction) async {
                                  bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      content:
                                          Text("Delete this announcement?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await _deleteAnnouncement(index);
                                  } else {
                                    _handleRefresh(); // Refresh to undo dismissal
                                  }
                                },
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Marquee(
                                          text: announcementList[index],
                                          style: const TextStyle(
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          velocity: 50.0,
                                          blankSpace: 150,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: _addAnnouncement,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[800]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          height: 50,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              "Add New Announcement",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
