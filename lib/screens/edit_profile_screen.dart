import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String? initialAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
    this.initialAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  String? _avatarUrl; // ảnh hiện có trên Supabase
  Uint8List? _pickedBytes; // ảnh vừa chọn, chưa upload
  String _pickedExt = 'jpg';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Lấy đuôi file, chỉ nhận png / webp, còn lại coi là jpg
  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return 'jpg';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return (ext == 'png' || ext == 'webp') ? ext : 'jpg';
  }

  String _contentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return; // người dùng bấm hủy
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pickedExt = _extensionOf(picked.name);
      });
    } catch (_) {
      EasyLoading.showError('Không mở được ảnh, vui lòng thử lại.');
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background(context),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library,
                  color: AppColors.title(sheetContext)),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_camera, color: AppColors.title(sheetContext)),
              title: const Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    EasyLoading.show(status: 'Đang lưu hồ sơ...');
    try {
      var avatarUrl = _avatarUrl;

      // Có chọn ảnh mới thì upload lên Storage, tên file có mốc thời gian
      // để ảnh cũ trong bộ nhớ đệm không bị hiện lại
      final bytes = _pickedBytes;
      if (bytes != null) {
        final path =
            '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$_pickedExt';
        await _client.storage.from('avatars').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: _contentType(_pickedExt)),
            );
        avatarUrl = _client.storage.from('avatars').getPublicUrl(path);
      }

      final phone = _phoneController.text.trim();
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'phone': phone.isEmpty ? null : phone,
        'avatar_url': avatarUrl,
      });

      EasyLoading.dismiss();
      if (!mounted) return;
      Navigator.pop(context, true); // true = có thay đổi, màn Tài khoản tải lại
    } on StorageException {
      EasyLoading.showError('Không upload được ảnh, vui lòng thử lại.');
    } on PostgrestException {
      EasyLoading.showError('Không lưu được hồ sơ, vui lòng thử lại.');
    } catch (_) {
      EasyLoading.showError('Có lỗi xảy ra, vui lòng thử lại.');
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.title(context)),
        filled: true,
        fillColor: AppColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final email = _client.auth.currentUser?.email ?? '';
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    ImageProvider? avatarImage;
    final pickedBytes = _pickedBytes;
    final avatarUrl = _avatarUrl;
    if (pickedBytes != null) {
      avatarImage = MemoryImage(pickedBytes);
    } else if (avatarUrl != null) {
      avatarImage = CachedNetworkImageProvider(avatarUrl);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SỬA HỒ SƠ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _chooseSource,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.button(context),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                              ),
                            )
                          : null,
                    ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepOrange,
                        child: Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _chooseSource,
                child: Text('Đổi ảnh đại diện',
                    style: TextStyle(color: AppColors.title(context))),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputStyle('Họ và tên', Icons.person),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _inputStyle(
                    'Số điện thoại (không bắt buộc)', Icons.phone),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  if (!RegExp(r'^0\d{9}$').hasMatch(text)) {
                    return 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Email là tên đăng nhập nên chỉ cho xem, không cho sửa
              TextFormField(
                initialValue: email,
                enabled: false,
                decoration: _inputStyle('Email', Icons.email),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button(context),
                    foregroundColor: Colors.amberAccent,
                  ),
                  onPressed: _save,
                  child: const Text('LƯU THAY ĐỔI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}