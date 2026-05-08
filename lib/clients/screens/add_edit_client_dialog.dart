import 'package:flutter/material.dart';
import '../data/clients_ffi.dart';
import '../../auth/data/session_ffi.dart';
import 'clients_screen.dart'; // To access the Client model

const kBackgroundColor = Color(0xFF0F171E);
const kAccentColor = Color(0xFF007AFF);
const kFieldFillColor = Color(0xFF1E272E); 
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF8E99A3);
const kDividerColor = Color(0xFF2C363F);

class AddEditClientDialog extends StatefulWidget {
  final Client? client;
  
  const AddEditClientDialog({super.key, this.client});

  @override
  State<AddEditClientDialog> createState() => _AddEditClientDialogState();
}

class _AddEditClientDialogState extends State<AddEditClientDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      nameController.text = widget.client!.name;
      phoneController.text = widget.client!.phone;
      emailController.text = widget.client!.email;
      addressController.text = widget.client!.address;
      // We don't fetch notes in the main list currently, so it might be empty
    }
  }

  void _saveClient() {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      _showSnackBar("Please fill required fields (Name & Phone)", Colors.orange);
      return;
    }

    final userId = SessionNativeAPI.instance.getCurrentUserId();
    int result;

    if (isEditing) {
      result = ClientsFFI.instance.updateClient(
        userId: userId,
        clientId: widget.client!.id,
        name: nameController.text,
        phone: phoneController.text,
        email: emailController.text,
        address: addressController.text,
        notes: notesController.text,
      );
    } else {
      result = ClientsFFI.instance.addClient(
        userId: userId,
        name: nameController.text,
        phone: phoneController.text,
        email: emailController.text,
        address: addressController.text,
        notes: notesController.text,
      );
    }

    if (result == 0) { 
      Navigator.pop(context, true); 
      _showSnackBar(isEditing ? "Client updated successfully!" : "Client added successfully!", Colors.green);
    } else if (result == -5) { // FFI_ERROR_INVALID_INPUT
      _showSnackBar("Invalid data provided!", Colors.red);
    } else if (result == -301) { // FFI_ERROR_CLI_PHONE_EXISTS
      _showSnackBar("Phone number already exists!", Colors.orange);
    } else {
      _showSnackBar("Error occurred (Code: $result)", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width > 700 ? 650 : double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kDividerColor),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(isEditing ? Icons.edit : Icons.person_add_alt_1, color: kAccentColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(isEditing ? 'Edit Client' : 'Add New Client', style: const TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kTextSecondary)),
                ],
              ),
              const SizedBox(height: 32),

              _buildLabel("Full Name", isRequired: true),
              _buildTextField(hint: "John Doe", controller: nameController),
              
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Phone Number", isRequired: true),
                        _buildTextField(hint: "+1 234 567 890", icon: Icons.phone_outlined, controller: phoneController),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Email (Optional)"),
                        _buildTextField(hint: "john@example.com", controller: emailController),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _buildLabel("Address"),
              _buildTextField(hint: "123 Main Street...", icon: Icons.location_on_outlined, controller: addressController),

              const SizedBox(height: 20),
              _buildLabel("Notes"),
              _buildTextField(hint: "Additional info...", icon: Icons.description_outlined, maxLines: 3, controller: notesController),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: _saveClient,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: kAccentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEditing ? 'Save Changes' : 'Add Client', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          if (isRequired) const Text(" *", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTextField({required String hint, IconData? icon, int maxLines = 1, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: kTextSecondary, size: 18) : null,
        filled: true,
        fillColor: kFieldFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kDividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccentColor, width: 1.2)),
      ),
    );
  }
}