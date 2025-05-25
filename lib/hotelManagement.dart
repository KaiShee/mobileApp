import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HotelManagement extends StatefulWidget {
  @override
  _HotelManagementState createState() => _HotelManagementState();
}

class _HotelManagementState extends State<HotelManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedLocation = 'All';
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> _locations = ['All'];
  
  // Image upload variables
  File? _selectedHotelImage;
  bool _isUploadingImage = false;
  Map<String, File?> _hotelImages = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _requestPermissions();
  }

  // Request necessary permissions for image upload
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.photos.request().isGranted &&
          await Permission.storage.request().isGranted) {
        return true;
      }
      
      if (await Permission.photos.isPermanentlyDenied ||
          await Permission.storage.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Storage permissions are required to upload images.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  // Pick image from gallery
  Future<File?> _pickImage() async {
    try {
      final hasPermission = await _requestPermissions();
      if (!hasPermission) return null;
      
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        // Verify the file exists before returning
        if (await file.exists()) {
          return file;
        } else {
          print('Selected image file does not exist: ${pickedFile.path}');
          return null;
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: ${e.toString()}')),
      );
    }
    return null;
  }

  // Save the image locally and get a file reference
  Future<File?> _saveImageLocally(dynamic imageFile, String hotelId) async {
    try {
      // Check if imageFile is null or not a File type
      if (imageFile == null) {
        print('Error: imageFile is null');
        return null;
      }
      
      // Ensure we have a File object
      final File fileToSave = imageFile is File 
          ? imageFile 
          : File(imageFile.toString());
          
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newImagePath = '${appDocDir.path}/hotel_${hotelId}_$timestamp.png';
      
      // Check if source file exists
      final exists = await fileToSave.exists();
      if (!exists) {
        print('Source image file does not exist: ${fileToSave.path}');
        return null;
      }
      
      print('Copying file from ${fileToSave.path} to $newImagePath');
      final File newImage = await fileToSave.copy(newImagePath);
      
      // Verify the new file was created
      final newExists = await newImage.exists();
      print('New image file created successfully: $newExists at path: ${newImage.path}');
      
      return newImage;
    } catch (e) {
      print('Error saving image locally: $e');
      return null;
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImageToStorage(File imageFile, String hotelId) async {
    try {
      setState(() => _isUploadingImage = true);
      
      final storageRef = _storage.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fileName = 'room_images/${hotelId}_$timestamp.jpg';
      final Reference imageRef = storageRef.child(fileName);
      
      // Add metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpg',
        customMetadata: {
          'hotelId': hotelId,
          'uploadDate': DateTime.now().toIso8601String(),
        },
      );
      
      // Upload the file
      final uploadTask = await imageRef.putFile(imageFile, metadata);
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
      );
      return null;
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // Select image for a specific hotel
  Future<void> _selectHotelImage(String hotelId) async {
    final File? imageFile = await _pickImage();
    if (imageFile != null) {
      final File? savedImage = await _saveImageLocally(imageFile, hotelId);
      if (savedImage != null) {
        setState(() {
          _hotelImages[hotelId] = savedImage;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected! Click "Save" to update the hotel image.'),
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Save Now',
              onPressed: () => _uploadAndSaveHotelImage(hotelId),
            ),
          ),
        );
      }
    }
  }

  // Upload and save hotel image
  Future<void> _uploadAndSaveHotelImage(String hotelId) async {
    try {
      final selectedImage = _hotelImages[hotelId];
      if (selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select an image first')),
        );
        return;
      }
      
      setState(() => _isUploadingImage = true);
      
      // Get the local file path
      final String localImagePath = selectedImage.path;
      print('Using local image path: $localImagePath');
      
      // Check if file exists
      final file = File(localImagePath);
      final exists = await file.exists();
      print('File exists at path $localImagePath: $exists');
      
      if (!exists) {
        print('Warning: File does not exist at path: $localImagePath');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Selected image file not found'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Try to save the image again
        final File? savedImage = await _saveImageLocally(selectedImage, hotelId);
        if (savedImage != null) {
          print('Successfully re-saved image to: ${savedImage.path}');
          
          // Update Firestore document with the new local path
          await _firestore.collection('hotels').doc(hotelId).update({
            'hotelUrl': savedImage.path,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('Hotel image updated in Firestore with new path: ${savedImage.path}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hotel image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Update the image map with the new file
          setState(() {
            _hotelImages[hotelId] = savedImage;
          });
          
          return;
        }
      }
      
      // Update Firestore document with the local path
      await _firestore.collection('hotels').doc(hotelId).update({
        'hotelUrl': localImagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Hotel image updated in Firestore with path: $localImagePath');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hotel image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Force refresh the UI
      setState(() {});
    } catch (e) {
      print('Error in uploadAndSaveHotelImage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update hotel image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('hotels').get();
      final Set<String> locations = {'All'};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['location'] != null) {
          locations.add(data['location'].toString());
        }
      }
      
      setState(() {
        _locations = locations.toList();
      });
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  bool _filterHotel(Map<String, dynamic> hotelData) {
    final name = hotelData['name']?.toString().toLowerCase() ?? '';
    final location = hotelData['location']?.toString() ?? '';

    bool matchesSearch = name.contains(_searchQuery.toLowerCase());
    bool matchesLocation = _selectedLocation == 'All' || location == _selectedLocation;

    return matchesSearch && matchesLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Hotels',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            tooltip: 'Add New Hotel',
            onPressed: () => _showAddHotelDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters Section
          Container(
            color: Colors.blue[800],
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search hotels...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Filters
                if (_showFilters) ...[
                  // Location Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Location',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        value: _selectedLocation,
                        items: _locations.map((location) {
                          return DropdownMenuItem(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocation = value ?? 'All';
                          });
                        },
                      ),
                    ),
                  ),
                ],
                // Bottom decoration
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hotels List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await _loadLocations();
              },
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('hotels').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Filter hotels based on search and filters
                  final filteredHotels = snapshot.data!.docs.where((doc) {
                    final hotelData = doc.data() as Map<String, dynamic>;
                    return _filterHotel(hotelData);
                  }).toList();

                  if (filteredHotels.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredHotels.length,
                    itemBuilder: (context, index) {
                      final hotel = filteredHotels[index];
                      final hotelData = hotel.data() as Map<String, dynamic>;
                      
                      // Check if local image exists
                      if (hotelData['hotelUrl'] != null && _isLocalPath(hotelData['hotelUrl'])) {
                        _checkFileExists(hotelData['hotelUrl']);
                      }

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hotel Image Section
                            Stack(
                              children: [
                                // Hotel Image
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  child: hotelData['hotelUrl'] != null
                                      ? _isLocalPath(hotelData['hotelUrl'])
                                          ? Image.file(
                                              File(hotelData['hotelUrl']),
                                              fit: BoxFit.cover,
                                              key: ValueKey<String>(hotelData['hotelUrl']),
                                              errorBuilder: (context, error, stackTrace) {
                                                print('Error loading image: $error');
                                                _checkFileExists(hotelData['hotelUrl']);
                                                return _buildPlaceholderImage();
                                              },
                                            )
                                          : Image.network(
                                              hotelData['hotelUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                print('Error loading network image: $error');
                                                return _buildPlaceholderImage();
                                              },
                                            )
                                      : _hotelImages[hotel.id] != null
                                          ? Image.file(
                                              _hotelImages[hotel.id]!,
                                              fit: BoxFit.cover,
                                              key: ValueKey<String>(_hotelImages[hotel.id]!.path),
                                              errorBuilder: (context, error, stackTrace) {
                                                print('Error loading image: $error');
                                                return _buildPlaceholderImage();
                                              },
                                            )
                                          : _buildPlaceholderImage(),
                                ),
                                // Image Upload Button
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: InkWell(
                                    onTap: _isUploadingImage
                                        ? null
                                        : () => _selectHotelImage(hotel.id),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Colors.blue[800],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                // Save Button (only show if image selected)
                                if (_hotelImages[hotel.id] != null && 
                                    (hotelData['hotelUrl'] == null || 
                                     _hotelImages[hotel.id]!.path != hotelData['hotelUrl']))
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: InkWell(
                                      onTap: _isUploadingImage
                                          ? null
                                          : () => _uploadAndSaveHotelImage(hotel.id),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Save Image',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                // Loading Indicator
                                if (_isUploadingImage)
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                // Hotel Rating
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[800],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.yellow,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${hotelData['averageRating'] ?? '0.0'}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Hotel Details
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          hotelData['name'] ?? 'Unnamed Hotel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 20, color: Colors.grey[700]),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          hotelData['location'] ?? 'No location specified',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.hotel, size: 20, color: Colors.grey[700]),
                                      SizedBox(width: 4),
                                      Text(
                                        '${hotelData['numFloors'] ?? 0} floors',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(Icons.rate_review, size: 20, color: Colors.grey[700]),
                                      SizedBox(width: 4),
                                      Text(
                                        '${hotelData['reviewCount'] ?? 0} reviews',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: Icon(Icons.edit, size: 18),
                                        label: Text('Edit'),
                                        onPressed: () => _showEditHotelDialog(context, hotel.id, hotelData),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue[800],
                                          side: BorderSide(color: Colors.blue[800]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: Icon(Icons.delete, size: 18),
                                        label: Text('Delete'),
                                        onPressed: () => _showDeleteConfirmation(context, hotel.id),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ],
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHotelDialog(context),
        icon: Icon(Icons.add),
        label: Text('Add Hotel'),
        backgroundColor: Colors.blue[800],
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue[800])!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (color ?? Colors.blue[800])!.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? Colors.blue[800],
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.blue[800],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder image for hotels without images
  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hotel,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8),
            Text(
              'No Image Available',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Tap camera icon to add',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddHotelDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final numFloorsController = TextEditingController();
    File? selectedImage;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add New Hotel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Selection
                InkWell(
                  onTap: () async {
                    final image = await _pickImage();
                    if (image != null) {
                      setState(() {
                        selectedImage = image;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Builder(
                      builder: (context) {
                        if (selectedImage != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading selected image: $error');
                                return _buildPlaceholderImage();
                              },
                            ),
                          );
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[500],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Hotel Image',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Hotel Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.hotel),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: numFloorsController,
                  decoration: InputDecoration(
                    labelText: 'Number of Floors',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.layers),
                    hintText: 'Enter total number of floors',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || 
                    locationController.text.isEmpty || 
                    numFloorsController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final numFloors = int.tryParse(numFloorsController.text);
                if (numFloors == null || numFloors <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid number of floors')),
                  );
                  return;
                }

                try {
                  setState(() => _isLoading = true);
                  
                  // First create hotel document
                  final docRef = await _firestore.collection('hotels').add({
                    'name': nameController.text,
                    'location': locationController.text,
                    'numFloors': numFloors,
                    'averageRating': 0,
                    'reviewCount': 0,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  // If image was selected, upload it
                  if (selectedImage != null) {
                    // Save the image locally
                    final File? savedImage = await _saveImageLocally(selectedImage, docRef.id);
                    if (savedImage != null) {
                      print('Adding hotel with new image path: ${savedImage.path}');
                      await _firestore.collection('hotels').doc(docRef.id).update({
                        'hotelUrl': savedImage.path,
                      });
                    }
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hotel added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding hotel: $e')),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditHotelDialog(BuildContext context, String hotelId, Map<String, dynamic> hotelData) async {
    final nameController = TextEditingController(text: hotelData['name']);
    final locationController = TextEditingController(text: hotelData['location']);
    final numFloorsController = TextEditingController(text: hotelData['numFloors']?.toString() ?? '0');
    File? selectedImage = _hotelImages[hotelId];
    final String? existingImageUrl = hotelData['hotelUrl'];

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Hotel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Selection
                InkWell(
                  onTap: () async {
                    final image = await _pickImage();
                    if (image != null) {
                      setState(() {
                        selectedImage = image;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Builder(
                      builder: (context) {
                        if (selectedImage != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading selected image: $error');
                                return _buildPlaceholderImage();
                              },
                            ),
                          );
                        } else if (existingImageUrl != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _isLocalPath(existingImageUrl)
                                ? Image.file(
                                    File(existingImageUrl),
                                    fit: BoxFit.cover,
                                    key: ValueKey<String>(existingImageUrl),
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Error loading local image in dialog: $error');
                                      _checkFileExists(existingImageUrl);
                                      return _buildPlaceholderImage();
                                    },
                                  )
                                : Image.network(
                                    existingImageUrl,
                                    fit: BoxFit.cover,
                                    key: ValueKey<String>(existingImageUrl),
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholderImage();
                                    },
                                  ),
                          );
                        } else {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey[500],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add Hotel Image',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Hotel Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.hotel),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: numFloorsController,
                  decoration: InputDecoration(
                    labelText: 'Number of Floors',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.layers),
                    hintText: 'Enter total number of floors',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || 
                    locationController.text.isEmpty || 
                    numFloorsController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final numFloors = int.tryParse(numFloorsController.text);
                if (numFloors == null || numFloors <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid number of floors')),
                  );
                  return;
                }

                try {
                  setState(() => _isLoading = true);
                  
                  // Prepare update data
                  final updateData = {
                    'name': nameController.text,
                    'location': locationController.text,
                    'numFloors': numFloors,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  
                  // Check if we need to update the image
                  if (selectedImage != null && selectedImage is File) {
                    // Save the image locally and get the path
                    print('Saving new image for hotel $hotelId');
                    final File? savedImage = await _saveImageLocally(selectedImage, hotelId);
                    if (savedImage != null) {
                      final savedPath = savedImage.path;
                      print('Successfully saved image locally to: $savedPath');
                      updateData['hotelUrl'] = savedPath;
                      print('Updating hotel with new image path: $savedPath');
                    } else {
                      print('Failed to save image locally');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save image'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }
                  
                  // Update hotel document
                  await _firestore.collection('hotels').doc(hotelId).set(
                    updateData,
                    SetOptions(merge: true),
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hotel updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating hotel: $e')),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String hotelId) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Hotel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this hotel?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone. All associated data including:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Hotel information', style: TextStyle(color: Colors.grey[600])),
                  Text('• Room details', style: TextStyle(color: Colors.grey[600])),
                  Text('• Booking history', style: TextStyle(color: Colors.grey[600])),
                  Text('• Reviews and ratings', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'will be permanently deleted.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('hotels').doc(hotelId).delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hotel deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting hotel: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete Hotel'),
          ),
        ],
      ),
    );
  }

  // Build error state widget
  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hotel,
            size: 80,
            color: Colors.blue[300],
          ),
          SizedBox(height: 16),
          Text(
            'No Hotels Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first hotel to get started',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddHotelDialog(context),
            icon: Icon(Icons.add),
            label: Text('Add Hotel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build no results state widget
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedLocation = 'All';
                _showFilters = false;
              });
            },
            icon: Icon(Icons.clear),
            label: Text('Clear Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[800],
              side: BorderSide(color: Colors.blue[800]!),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine if the path is a local file path
  bool _isLocalPath(String path) {
    return path.startsWith('/') || path.startsWith('C:') || path.contains('data/user') || path.contains('emulated');
  }
  
  // Debug method to check if a file exists
  void _checkFileExists(String path) {
    try {
      final file = File(path);
      final exists = file.existsSync();
      print('File at path $path exists: $exists');
      if (!exists) {
        // Try to get directory contents to see what's available
        final dir = Directory(path.substring(0, path.lastIndexOf('/')));
        if (dir.existsSync()) {
          print('Directory exists, contents:');
          dir.listSync().forEach((entity) {
            print(' - ${entity.path}');
          });
        } else {
          print('Directory does not exist: ${dir.path}');
        }
      }
    } catch (e) {
      print('Error checking file: $e');
    }
  }
}