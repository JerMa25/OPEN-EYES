// lib/widgets/add_contact_dialog.dart

import 'package:flutter/material.dart';
import '../../model/contact.dart';

class AddContactDialog extends StatefulWidget {
  final Contact? contact;
  final int canneId; // ✅ INT maintenant (pas String)

  const AddContactDialog({
    super.key,
    this.contact,
    required this.canneId, // ✅ Obligatoire et INT
  });

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  late final TextEditingController _nomController;
  late final TextEditingController _prenomController;
  late final TextEditingController _phoneController;
  String _selectedTypeContact = 'FAMILLE'; // ✅ Valeur par défaut

  // ✅ Types corrects selon le backend
  final List<Map<String, String>> _typeContacts = [
    {'value': 'FAMILLE', 'label': 'Famille'},
    {'value': 'AMI', 'label': 'Ami'},
    {'value': 'SOIGNANT', 'label': 'Soignant'},
    {'value': 'URGENCE', 'label': 'Service d\'urgence'},
    {'value': 'AUTRE', 'label': 'Autre'},
  ];

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.contact?.nom ?? '');
    _prenomController = TextEditingController(text: widget.contact?.prenom ?? '');
    _phoneController = TextEditingController(text: widget.contact?.telephone ?? '');
    
    // ✅ Check if contact type exists in list, otherwise default or add 'SUPER_ADMIN'
    if (widget.contact != null) {
      if (_typeContacts.any((t) => t['value'] == widget.contact!.typeContact)) {
        _selectedTypeContact = widget.contact!.typeContact;
      } else if (widget.contact!.typeContact == 'SUPER_ADMIN') {
         // Create a temporary entry for SUPER_ADMIN if encountered
         _typeContacts.add({'value': 'SUPER_ADMIN', 'label': 'Super Admin'});
         _selectedTypeContact = 'SUPER_ADMIN';
      } else {
        _selectedTypeContact = 'AUTRE'; // Fallback
      }
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
    // Validation
    if (_nomController.text.trim().isEmpty || 
        _prenomController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs requis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Créer le contact avec les bonnes données
    final contact = Contact(
      id: widget.contact?.id,
      canne: widget.canneId, // ✅ INT maintenant
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: _phoneController.text.trim(),
      typeContact: _selectedTypeContact,
      priorite: widget.contact?.priorite ?? 1,
    );

    Navigator.pop(context, contact); // ✅ Retourne un objet Contact
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Nom
              Text(
                'Nom',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nomController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Entrez le nom',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Prénom
              Text(
                'Prénom',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _prenomController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Entrez le prénom',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Téléphone
              Text(
                'Téléphone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+237690000000',
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[400]),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Type de contact
              Text(
                'Type de contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTypeContact,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined, color: Colors.grey[400]),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _typeContacts.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTypeContact = value!;
                  });
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? 'Mettre à jour' : 'Enregistrer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
    );
  }
}