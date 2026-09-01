import 'package:flutter/material.dart';
import '../models/ai_model.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class ModelSelectionSheet extends StatefulWidget {
  final String initialSelection;

  const ModelSelectionSheet({super.key, required this.initialSelection});

  @override
  State<ModelSelectionSheet> createState() => _ModelSelectionSheetState();
}

class _ModelSelectionSheetState extends State<ModelSelectionSheet> {
  late String _selectedModel;
  
  List<AiModel> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.initialSelection;
    _fetchModelsFromBackend();
  }

  // Fetch model list from FastAPI backend
  Future<void> _fetchModelsFromBackend() async {
    try {
      // 10.0.2.2 connects Android emulator to host localhost
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/models'));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> backendModels = data['models'];
        
        if (!mounted) return;
        setState(() {
          _models = backendModels.map((item) {
            return AiModel(
              item['name'] ?? 'Unknown Model',
              'Provider: ${item['provider'] ?? 'Unknown'}',
              item['supports_image_generation'] ?? false,
              Icons.auto_awesome,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        print('Server returned error: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Connection failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title
          const Center(
            child: Text(
              'Select Model & Tool',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'AI Models',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Grid of models
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _models.isEmpty 
                  ? const Center(child: Text('No models found in database.'))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        final model = _models[index];
                        final isSelected = model.name == _selectedModel;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedModel = model.name;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.grey.shade100 : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Colors.black : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(model.icon, size: 20),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            model.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        model.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Icon(Icons.info, size: 16, color: Colors.grey.shade400),
                                    ),
                                  ],
                                ),
                              ),
                              // PRO Badge
                              if (model.isPro)
                                Positioned(
                                  top: -6,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          
          // Select Button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _selectedModel);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Select',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
