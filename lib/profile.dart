import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'login.dart';
import 'services/firebase_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _imageSelected = false;
  
  UserModel? _userModel;
  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _verifyFirebaseStorage();
    
    // Load profile image after a small delay to ensure latest data
    Future.delayed(Duration(milliseconds: 100), () {
      loadProfileImage();
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _userService.getUserById(user.uid);
        setState(() {
          _userModel = userData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadUserData,
            ),
          ),
        );
      }
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13 and above (SDK 33+)
      if (await Permission.photos.request().isGranted &&
          await Permission.storage.request().isGranted) {
        return true;
      }
      
      // Show settings dialog if permissions are permanently denied
      if (await Permission.photos.isPermanentlyDenied ||
          await Permission.storage.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: Text('Permissions Required'),
              content: Text('Storage permissions are required to upload images. Please enable them in settings.'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Open Settings'),
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  // Clean up temporary image files
  Future<void> cleanupTemporaryFiles() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory(appDocDir.path);
      
      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;
      
      final List<FileSystemEntity> files = directory.listSync();
      int filesRemoved = 0;
      
      for (FileSystemEntity file in files) {
        if (file is File) {
          // Only delete files that are:
          // 1. Temporary profile images
          // 2. Default profile.png
          // 3. Profile images from other users
          if ((file.path.contains('profile_temp_') && file.path.endsWith('.png')) ||
              file.path.endsWith('profile.png') ||
              (file.path.contains('profile_') && 
               !file.path.contains(currentUserId ?? 'no_user'))) {
            try {
              await file.delete();
              filesRemoved++;
              print('Removed file: ${file.path}');
            } catch (e) {
              print('Error removing file ${file.path}: $e');
            }
          }
        }
      }
      
      print('Cleaned up $filesRemoved files');
    } catch (e) {
      print('Error cleaning up temporary files: $e');
    }
  }

  // Get image from gallery
  Future getImageFromGallery() async {
    try {
      // Request permissions first
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        print('Permissions not granted');
        return;
      }
      
      // Clean up old temporary files
      await cleanupTemporaryFiles();
      
      print('Attempting to pick image from gallery...');
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Slightly reduce quality to improve upload speed
      );
      
      if (pickedFile != null) {
        print('Image picked successfully: ${pickedFile.path}');
        
        // Create a new file object from the picked file to ensure we have a fresh reference
        final pickedImageFile = File(pickedFile.path);
        
        setState(() {
          // Update the image with the new picked file
          _image = pickedImageFile;
          _imageSelected = true;
        });
        
        // We'll save locally but not upload yet
        try {
          await savePicture();
          print('Image saved locally');
          
          // Show a snackbar indicating image is selected
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image selected! Click "Save Profile" to update your profile picture.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        } catch (saveError) {
          print('Error saving picture locally: $saveError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving image locally: ${saveError.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      String errorMessage = 'Error selecting image';
      
      // Provide more specific error messages based on error type
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please grant storage access in settings.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorMessage: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  // Save picture to local storage
  Future<void> savePicture() async {
    if (_image != null) {
      try {
        print('Saving picture to local storage...');
        print('Original image path: ${_image!.path}');
        
        // Get current user
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }
        
        // Get app documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        print('App documents directory: ${appDocDir.path}');
        
        // Create a new filename with user ID and timestamp to ensure uniqueness
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newImagePath = '${appDocDir.path}/profile_temp_${user.uid}_$timestamp.png';
        print('Target image path: $newImagePath');
        
        // Check if the source file exists
        if (!await _image!.exists()) {
          print('Source file does not exist: ${_image!.path}');
          throw Exception('Source image file does not exist');
        }
        
        // Create a copy of the file
        final newFile = await _image!.copy(newImagePath);
        print('File copied successfully to: ${newFile.path}');
        
        // Update the image reference
        setState(() {
          _image = newFile;
        });
        print('Image reference updated');
        
        // Verify the new file exists
        if (await newFile.exists()) {
          print('Verification: New file exists at ${newFile.path}');
          print('File size: ${await newFile.length()} bytes');
        } else {
          print('Warning: Verification failed - New file does not exist');
        }
      } catch (e) {
        print('Error copying image: $e');
        if (e.toString().contains('permission-denied')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Storage permission denied. Please check app permissions.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        throw e; // Rethrow to handle in calling function
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Profile Image'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('No Image Selected'),
                Text('Please select an image first.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  // Load profile image from local storage or path stored in Firestore
  Future<void> loadProfileImage() async {
    try {
      print('Loading profile image...');
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        setState(() {
          _image = null;
        });
        return;
      }
      
      // Clean up any other users' images first
      await cleanupTemporaryFiles();
      
      // If we already have user data with profileImageUrl
      if (_userModel?.profileImageUrl != null && 
          _userModel!.profileImageUrl!.isNotEmpty && 
          _userModel!.profileImageUrl!.contains(user.uid)) {
        final imagePath = _userModel!.profileImageUrl!;
        print('Profile image path from Firestore: $imagePath');
        
        // Check if it's a local file path
        if (imagePath.startsWith('/')) {
          final file = File(imagePath);
          if (await file.exists()) {
            print('File exists at path: ${file.path}');
            setState(() {
              _image = file;
            });
            return;
          } else {
            print('File does not exist at path: ${imagePath}');
          }
        }
      }
      
      // Try to find any existing profile image for this user
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory(appDocDir.path);
      if (await directory.exists()) {
        final List<FileSystemEntity> files = directory.listSync();
        for (var file in files) {
          if (file is File && 
              file.path.contains('profile_${user.uid}') && 
              await file.exists()) {
            setState(() {
              _image = file;
              print('Found existing profile image: ${file.path}');
            });
            return;
          }
        }
      }
      
      // If no image is found, clear the image state
      print('No profile image found for current user');
      setState(() {
        _image = null;
      });
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() {
        _image = null;
      });
    }
  }

  // Save profile image locally and update profileImageUrl
  Future<void> uploadImageToFirebase() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    try {
      // Set loading state
      setState(() => _isUploadingImage = true);
      
      // Dismiss any Firebase error messages first
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      print('Starting image save process...');

      // Check for user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Error: User not logged in');
        throw Exception('User not logged in');
      }

      // Check if file exists and is readable
      if (!await _image!.exists()) {
        print('Error: Image file does not exist at path: ${_image!.path}');
        throw Exception('Image file does not exist');
      }
      
      print('File exists at path: ${_image!.path}');
      print('File size: ${await _image!.length()} bytes');

      // Save the image to a permanent location
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${user.uid}_$timestamp.png';
      final finalImagePath = '${appDocDir.path}/$fileName';
      
      print('Saving image to: $finalImagePath');
      
      // Create directory if it doesn't exist
      final directory = Directory(appDocDir.path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Delete old profile images for this user
      final List<FileSystemEntity> files = directory.listSync();
      for (var file in files) {
        if (file is File && 
            file.path.contains('profile_${user.uid}') && 
            file.path != _image!.path) {
          try {
            await file.delete();
            print('Deleted old profile image: ${file.path}');
          } catch (e) {
            print('Error deleting old file: $e');
          }
        }
      }
      
      // Copy the image to the permanent location
      final File savedFile = await _image!.copy(finalImagePath);
      if (!await savedFile.exists()) {
        throw Exception('Failed to save image to permanent location');
      }
      
      print('Image saved successfully to: $finalImagePath');
      
      // Also save as user-specific profile.png
      final userProfilePath = '${appDocDir.path}/profile_${user.uid}.png';
      await _image!.copy(userProfilePath);
      print('Image also saved to user-specific path: $userProfilePath');
      
      // Store just the path as a string in Firestore
      print('Updating profileImageUrl with path: $finalImagePath');
      
      // Update Firestore with just the path string
      try {
        // Method 1: Using UserService
        await _userService.updateUserFields(user.uid, {
          'profileImageUrl': finalImagePath,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('User profile updated via UserService with local path');
      } catch (serviceError) {
        print('Error updating via UserService: $serviceError');
        
        // Method 2: Direct Firestore update as fallback
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profileImageUrl': finalImagePath,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('User profile updated via direct Firestore update with local path');
      }
      
      // Update local model
      if (_userModel != null) {
        setState(() {
          _userModel = _userModel!.copyWith(
            profileImageUrl: finalImagePath,
            localProfileImagePath: userProfilePath,
          );
          _isUploadingImage = false;
          _imageSelected = false;
        });
        print('Local user model updated with image path');
      }

      // Clean up temporary files now that we've successfully saved
      await cleanupTemporaryFiles();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile picture saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload user data to ensure we have the latest
      await _loadUserData();
      await loadProfileImage(); // Explicitly reload the image
      print('User data reloaded from database');
      
    } catch (e) {
      print('Error in saving profile image: $e');
      
      // Always ensure we reset the loading state
      setState(() => _isUploadingImage = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save image: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Verify Firebase Storage configuration
  Future<void> _verifyFirebaseStorage() async {
    try {
      print('Verifying Firebase Storage configuration...');
      final FirebaseStorage storage = FirebaseStorage.instance;
      
      // Get storage bucket
      final String bucket = storage.bucket;
      print('Firebase Storage bucket: $bucket');
      
      // Try to list files to verify access
      final ListResult result = await storage.ref('profile_images').list(const ListOptions(maxResults: 1));
      print('Firebase Storage access verified. Found ${result.items.length} items in profile_images directory.');
      
    } catch (e) {
      print('Firebase Storage configuration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Storage not properly configured: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // Show instructions for Firebase Storage setup
  void _showFirebaseSetupInstructions() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Firebase Storage Setup Required'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Firebase Storage is not properly configured. Please follow these steps:'),
                SizedBox(height: 16),
                Text('1. Go to the Firebase Console (console.firebase.google.com)'),
                Text('2. Select your project'),
                Text('3. Click on "Storage" in the left navigation'),
                Text('4. Follow the setup instructions to initialize Firebase Storage'),
                Text('5. Make sure your Storage rules allow image uploads'),
                SizedBox(height: 16),
                Text('Example Storage Rules:'),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'rules_version = \'2\';\nservice firebase.storage {\n  match /b/{bucket}/o {\n    match /profile_images/{userId}/{allPaths=**} {\n      allow read: if true;\n      allow write: if request.auth != null && request.auth.uid == userId;\n    }\n  }\n}',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context) {
    if (_userModel == null) return;

    final TextEditingController nameController = TextEditingController(text: _userModel!.name);
    final TextEditingController phoneController = TextEditingController(text: _userModel!.phoneNumber);
    String? phoneError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Edit Profile"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Email: ${_userModel!.email}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: phoneError,
                        prefixText: "+60 ",
                      ),
                      onChanged: (value) {
                        // Remove any non-digit characters
                        String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                        
                        // Validate phone number
                        if (digitsOnly.isNotEmpty) {
                          if (!digitsOnly.startsWith('1')) {
                            setState(() {
                              phoneError = 'Phone number must start with 01';
                            });
                          } else if (digitsOnly.length < 9 || digitsOnly.length > 12) {
                            setState(() {
                              phoneError = 'Phone number must be between 9-12 digits';
                            });
                          } else {
                            setState(() {
                              phoneError = null;
                            });
                          }
                        } else {
                          setState(() {
                            phoneError = null;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _userModel!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: _userModel!.isAdmin ? Colors.blue[800] : Colors.grey[600],
                        ),
                        SizedBox(width: 8),
                        Text(
                          _userModel!.isAdmin ? "Admin User" : "Regular User",
                          style: TextStyle(
                            color: _userModel!.isAdmin ? Colors.blue[800] : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: phoneError != null ? null : () async {
                    try {
                      // Validate phone number before saving
                      String phoneNumber = phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
                      if (!phoneNumber.startsWith('1') || phoneNumber.length < 9 || phoneNumber.length > 12) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid phone number')),
                        );
                        return;
                      }

                      await _userService.updateUserFields(_userModel!.id, {
                        'name': nameController.text,
                        'phoneNumber': phoneNumber,
                      });
                      await _loadUserData();
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text("Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      setState(() => _isLoading = true);
      
      // Get the current user ID before logout
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      // Clear the image cache and state
      setState(() {
        _image = null;
        _imageSelected = false;
        _userModel = null;
      });

      // Clean up all profile images
      await cleanupTemporaryFiles();
      
      // Also explicitly delete the user-specific profile image if it exists
      if (userId != null) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final userProfilePath = '${appDocDir.path}/profile_$userId.png';
          final userProfileFile = File(userProfilePath);
          if (await userProfileFile.exists()) {
            await userProfileFile.delete();
            print('Deleted user profile image: $userProfilePath');
          }
        } catch (e) {
          print('Error deleting user profile image: $e');
        }
      }
      
      await _authService.signOut();
      
      if (!mounted) return;
      
      // Navigate to login page and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileInitials() {
    final String initials = _userModel?.name.split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join('')
        .toUpperCase() ?? 'U';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[300]!, Colors.blue[700]!],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Handle profile image which could be either a file path or URL
  Widget _handleProfileImage(String imagePathOrUrl) {
    print('Handling profile image: $imagePathOrUrl');
    
    // Check if it's a file path
    if (imagePathOrUrl.startsWith('/')) {
      // It's a file path
      final file = File(imagePathOrUrl);
      
      // Check if file exists
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          // Add debug output for the file existence check
          if (snapshot.connectionState == ConnectionState.done) {
            print('File existence check result: ${snapshot.data}');
            
            if (snapshot.data == true) {
              // File exists, show it
              print('Loading image from file: ${file.path}');
              print('File size: ${file.lengthSync()} bytes');
              
              // Force image refresh by adding a timestamp parameter to the key
              return Image.file(
                file,
                fit: BoxFit.cover,
                // Use current timestamp to force refresh
                key: ValueKey<String>('${file.path}?t=${DateTime.now().millisecondsSinceEpoch}'),
                cacheHeight: 300, // Specify optimal cache size for profile picture
                cacheWidth: 300,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image file: $error');
                  return _buildProfileInitials();
                },
              );
            } else {
              // File doesn't exist
              print('Image file not found: ${file.path}');
              return _buildProfileInitials();
            }
          } else {
            // Still checking if file exists
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    } else if (imagePathOrUrl.startsWith('http')) {
      // It's a URL, handle it as before
      print('Loading image from URL: $imagePathOrUrl');
      return Image.network(
        imagePathOrUrl,
        fit: BoxFit.cover,
        // Disable caching to force fresh load
        cacheHeight: 300,
        cacheWidth: 300,
        // Add a cache-busting parameter
        key: ValueKey<String>('${imagePathOrUrl}?t=${DateTime.now().millisecondsSinceEpoch}'),
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image from URL: $error');
          return _buildProfileInitials();
        },
      );
    } else if (imagePathOrUrl.isEmpty) {
      print('Empty image path/URL');
      return _buildProfileInitials();
    } else {
      // Neither a valid path nor URL
      print('Invalid image path/URL: $imagePathOrUrl');
      return _buildProfileInitials();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              SizedBox(height: 16),
              Text(
                "Loading profile...", 
                style: TextStyle(color: theme.colorScheme.onBackground),
              ),
            ],
          ),
        ),
      );
    }

    if (_userModel == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_outlined, 
                size: 80, 
                color: theme.colorScheme.onBackground.withOpacity(0.6)
              ),
              SizedBox(height: 16),
              Text(
                "Please log in to view your profile",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.login),
                label: Text("Login"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Main profile screen
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, 
            color: theme.colorScheme.onBackground, 
            size: 20
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onBackground),
            tooltip: "Edit Profile",
            onPressed: () => _showEditDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await loadProfileImage();
        },
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Profile Header with Image
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    // Profile image with stack for edit button
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        // Profile image container
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? theme.colorScheme.surface : Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withOpacity(isDark ? 0.3 : 0.1),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _isUploadingImage
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                    ),
                                  )
                                : _image != null
                                    ? Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                        key: ValueKey<String>(_image!.path),
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildProfileInitials();
                                        },
                                      )
                                    : _userModel?.profileImageUrl != null
                                        ? _handleProfileImage(_userModel!.profileImageUrl!)
                                        : _buildProfileInitials(),
                          ),
                        ),
                        // Edit button
                        InkWell(
                          onTap: _isUploadingImage ? null : getImageFromGallery,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? theme.colorScheme.surface : Colors.white,
                                width: 2
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: theme.colorScheme.onPrimary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // User name and badge
                    Text(
                      _userModel!.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    SizedBox(height: 4),
                    
                    // User type badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      margin: EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: _userModel!.isAdmin 
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _userModel!.isAdmin ? Icons.verified_user : Icons.person,
                            size: 14,
                            color: _userModel!.isAdmin 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _userModel!.isAdmin ? "Admin" : "User",
                            style: TextStyle(
                              color: _userModel!.isAdmin 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Image selection buttons
                    if (_imageSelected && !_isUploadingImage) ...[
                      SizedBox(height: 16),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 32),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, 
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 18
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'New image selected',
                                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isUploadingImage ? null : uploadImageToFirebase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Contact Info Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSectionCard(
                  title: "Contact Information",
                  icon: Icons.contact_mail_outlined,
                  children: [
                    _buildContactItem(
                      icon: Icons.email_outlined,
                      title: "Email",
                      value: _userModel!.email,
                    ),
                    Divider(
                      height: 24,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                    _buildContactItem(
                      icon: Icons.phone_outlined,
                      title: "Phone",
                      value: _userModel!.phoneNumber,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Booking History Section
              if (_userModel!.bookingHistory.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionCard(
                    title: "Booking History",
                    icon: Icons.history,
                    children: [
                      ListView.separated(
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _userModel!.bookingHistory.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withOpacity(0.1),
                        ),
                        itemBuilder: (context, index) {
                          final booking = _userModel!.bookingHistory[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.hotel, 
                                color: theme.colorScheme.primary,
                                size: 20
                              ),
                            ),
                            title: Text(
                              "Booking #$booking",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onBackground,
                              ),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                              size: 16,
                              color: theme.colorScheme.onBackground.withOpacity(0.5),
                            ),
                            onTap: () {},
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
              
              // App Info
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16),
                color: isDark 
                  ? theme.colorScheme.surface
                  : theme.colorScheme.surfaceVariant,
                child: Column(
                  children: [
                    Text(
                      "EzyStay",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build a section card with title and icon
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 1,
      color: isDark ? theme.colorScheme.surface : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  // Build a contact information item
  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Reload everything when returning to this page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadAfterNavigation();
  }

  // Force reload after navigation
  Future<void> _reloadAfterNavigation() async {
    try {
      // Only reload if we were previously loaded
      if (!_isLoading && mounted) {
        print('Reloading data after navigation...');
        await _loadUserData();
        await loadProfileImage();
      }
    } catch (e) {
      print('Error reloading after navigation: $e');
    }
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primaryColor: Colors.blue[800],
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: Colors.blue[800]!,
        secondary: Colors.blue[600]!,
      ),
    ),
    darkTheme: ThemeData(
      primaryColor: Colors.blue[800],
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[600]!,
        secondary: Colors.blue[400]!,
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
      ),
    ),
    home: ProfilePage(),
  ));
}
