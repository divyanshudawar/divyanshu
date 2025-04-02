import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sgsits_gym/pages/signupPage.dart';

class AdminsHome extends StatefulWidget {
  const AdminsHome({super.key});

  @override
  State<AdminsHome> createState() => _AdminsHomeState();
}

class _AdminsHomeState extends State<AdminsHome> {
  List<DocumentSnapshot> _adminList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color _primaryColor = const Color(0xFF2196F3);
  bool _keyVerified = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminKey();
  }

  Future<void> _verifyAdminKey() async {
    // Show loading dialog

    try {
      // Get stored admin key
      final DocumentSnapshot keyDoc = await FirebaseFirestore.instance
          .collection('AdminKey')
          .doc('Admin-key')
          .get();

      if (!keyDoc.exists) {
        Navigator.pop(context);
        _showErrorAndExit('Admin key not configured properly');
        return;
      }

      final String storedKey = keyDoc.get('Key');
      Navigator.pop(context); // Close loading

      final String? enteredKey = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Admin Authentication'),
          content: TextField(
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter Admin Key',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final controller = (context
                        .findAncestorWidgetOfExactType<AlertDialog>()
                        ?.content as TextField)
                    .controller;
                Navigator.pop(context, controller?.text);
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      );

      if (enteredKey == null || enteredKey != storedKey) {
        _showErrorAndExit('Invalid admin key');
        return;
      }

      setState(() => _keyVerified = true);
      _fetchAdmins();
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showErrorAndExit('Error verifying admin key: ${e.toString()}');
    }
  }

  void _showErrorAndExit(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => Navigator.pop(context));
  }

  Future<void> _fetchAdmins() async {
    if (!_keyVerified) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final QuerySnapshot adminCollection =
          await FirebaseFirestore.instance.collection("Admins").get();
      setState(() {
        _adminList = adminCollection.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to fetch admins: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchAdmins();
  }

  @override
  Widget build(BuildContext context) {
    List<DocumentSnapshot> filteredAdmins = [];
    if (!_isLoading && _errorMessage == null) {
      filteredAdmins = _adminList.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String name = (data['firstName']?.toString() ?? '') +
            ' ' +
            (data['lastName']?.toString() ?? '');
        String email = data['email']?.toString().toLowerCase() ?? '';
        String mobile = data['mobileNumber']?.toString().toLowerCase() ?? '';

        String searchable = '$name $email $mobile'; // Simplified search
        return searchable.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 2,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Image.asset('assets/logo.jpeg'),
          ),
        ),
        title: const Text(
          "Manage Admins", // Changed title
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Signuppage(
                      isAdmin: true, // Make sure signup creates admins
                      isFromAdmin: true,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () {
          Navigator.pop(context);
          return Future.value(true);
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8, left: 8, right: 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search Admins...', // Changed hint
                            prefixIcon:
                                Icon(Icons.search, color: _primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _handleRefresh,
                          child: ListView.builder(
                            itemCount: filteredAdmins.length,
                            itemBuilder: (context, index) {
                              final adminData = filteredAdmins[index].data()
                                  as Map<String, dynamic>;
                              return _buildAdminCard(adminData);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> adminData) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.15,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey[100]!,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}", // Display name
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adminData['email'] ?? '', //Display email
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  adminData['mobileNumber'] ?? '', //Display mobile
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            Row(
              children: [
                _buildIconButton(Icons.call, "call", Colors.black, adminData),
                const SizedBox(width: 16),
                _buildIconButton(Icons.delete, "delete", Colors.red, adminData),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color,
      Map<String, dynamic> adminData) {
    return InkWell(
      onTap: () {
        if (label == 'delete') {
          _deleteAdmin(adminData['email']); // Use email as ID
        } else if (label == 'call') {
          _makePhoneCall(adminData['mobileNumber']);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdmin(String adminEmail) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this admin?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection("Admins")
            .where("email", isEqualTo: adminEmail) // Find the admin by email
            .get()
            .then((querySnapshot) {
          querySnapshot.docs.forEach((doc) {
            doc.reference.delete(); // Delete the document
          });
        });

        // Refresh the list
        _fetchAdmins();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin deleted successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete admin: $e")),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String mobileNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: mobileNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch phone app.")),
      );
    }
  }
}
