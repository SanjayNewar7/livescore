// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _blue = Color(0xFF1A62C8);
  static const Color _darkBlue = Color(0xFF0D3F85);
  static const Color _green = Color(0xFF16A34A);
  static const Color _ink = Color(0xFF0F1623);
  static const Color _muted = Color(0xFF6B7A96);
  static const Color _bg = Color(0xFFF5F7FB);

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  UserProfile _profile = UserProfile.empty;
  bool _isSaving = false;
  bool _isPickingImage = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _profile = ProfileService().profile;
    _nameController = TextEditingController(text: _profile.name);
    _bioController = TextEditingController(text: _profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = await ProfileService().updateBasicInfo(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );
    setState(() {
      _profile = updated;
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, updated);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close the sheet

    // Request permission
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showPermissionDenied('Camera');
        return;
      }
    } else {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showPermissionDenied('Gallery');
        return;
      }
    }

    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final updated = await ProfileService().saveProfileImage(File(image.path));
        if (updated != null && mounted) {
          setState(() => _profile = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _showPermissionDenied(String source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$source Access Denied'),
        content: Text(
          'Please enable $source access in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: _blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeImage() async {
    Navigator.pop(context);
    final updated = await ProfileService().removeProfileImage();
    if (mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed'),
          backgroundColor: _muted,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 20),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _muted),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            _buildSheetTile(
              icon: Icons.camera_alt_rounded,
              title: 'Take a Photo',
              subtitle: 'Capture a new profile picture',
              color: _blue,
              onTap: () => _pickImage(ImageSource.camera),
            ),
            _buildSheetTile(
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo',
              color: _green,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            if (_profile.hasImage)
              _buildSheetTile(
                icon: Icons.delete_outline_rounded,
                title: 'Remove Photo',
                subtitle: 'Remove your profile picture',
                color: Colors.red,
                onTap: _removeImage,
                isDestructive: true,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : _ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: _muted,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _blue,
              ),
            )
                : const Text(
              'Save',
              style: TextStyle(
                color: _blue,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Profile Photo ──────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _isPickingImage ? null : _showImagePickerSheet,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_blue, _darkBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: _profile.hasImage
                            ? Image.file(
                          File(_profile.imagePath!),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        )
                            : Container(
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              _profile.initials,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: _blue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isPickingImage
                            ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _profile.hasImage ? 'Tap to change photo' : 'Tap to add a photo',
                style: TextStyle(
                  fontSize: 12,
                  color: _muted,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Name Field ──────────────────────────────────────────────────
            _buildLabel('Full Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your name',
              icon: Icons.person_outline_rounded,
              maxLength: 40,
            ),
            const SizedBox(height: 20),

            // ── Bio Field ────────────────────────────────────────────────────
            _buildLabel('Bio'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _bioController,
              hint: 'Tell us about yourself',
              icon: Icons.edit_note_rounded,
              maxLength: 120,
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // ── Save Button ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Info Text ────────────────────────────────────────────────────
            Center(
              child: Text(
                'Your profile data is stored only on this device',
                style: TextStyle(
                  fontSize: 11,
                  color: _muted.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 15,
          color: _ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(
              left: 4,
              right: 4,
              bottom: maxLines > 1 ? 40 : 0,
            ),
            child: Icon(icon, size: 22, color: _blue),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          counterStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}