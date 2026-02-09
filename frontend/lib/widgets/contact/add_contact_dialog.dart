// lib/widgets/contact/add_contact_dialog.dart

import 'package:flutter/material.dart';
import '../../model/contact.dart';
import '../../config.dart';

/// Dialogue pour ajouter ou modifier un contact
class AddContactDialog extends StatefulWidget {
  final Contact? contact;
  final int canneId;

  const AddContactDialog({
    super.key,
    this.contact,
    required this.canneId,
  });

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  late final TextEditingController _nomController;
  late final TextEditingController _prenomController;
  late final TextEditingController _phoneController;
  late String _selectedTypeContact;
  
  final _formKey = GlobalKey<FormState>();

  List<Map<String, String>> get _typeContacts {
    final types = List<Map<String, String>>.from(AppConfig.contactTypes);
    if (widget.contact != null && 
        widget.contact!.typeContact == 'SUPER_ADMIN' &&
        !types.any((t) => t['value'] == 'SUPER_ADMIN')) {
      types.add({'value': 'SUPER_ADMIN', 'label': 'Super Admin'});
    }
    return types;
  }

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.contact?.nom ?? '');
    _prenomController = TextEditingController(text: widget.contact?.prenom ?? '');
    _phoneController = TextEditingController(text: widget.contact?.telephone ?? '');
    
    if (widget.contact != null) {
      final existingType = widget.contact!.typeContact;
      if (_typeContacts.any((t) => t['value'] == existingType)) {
        _selectedTypeContact = existingType;
      } else {
        _selectedTypeContact = 'AUTRE';
      }
    } else {
      _selectedTypeContact = 'FAMILLE';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.contact != null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final contact = Contact(
      id: widget.contact?.id,
      canne: widget.canneId,
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: _phoneController.text.trim(),
      typeContact: _selectedTypeContact,
      priorite: widget.contact?.priorite ?? 1,
    );

    Navigator.pop(context, contact);
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Modifier le contact' : 'Nouveau Contact',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isEditing
                      ? "Modifiez les informations du contact."
                      : "Ajoutez un contact pour la canne connectée.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Nom
                Text('Nom', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Entrez le nom', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Prénom
                Text('Prénom', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _prenomController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Entrez le prénom', Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le prénom est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Téléphone
                Text('Téléphone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('+237690000000', Icons.phone_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le téléphone est requis';
                    }
                    if (value.trim().length < 9) {
                      return 'Numéro invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Type de contact
                Text('Type de contact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTypeContact,
                  decoration: _inputDecoration('', Icons.category_outlined),
                  items: _typeContacts.map((type) {
                    return DropdownMenuItem(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedTypeContact = value!);
                  },
                ),
                const SizedBox(height: 32),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Annuler',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Mettre à jour' : 'Enregistrer',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
