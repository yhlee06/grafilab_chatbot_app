import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/ai_model.dart';
import '../config/api_config.dart';

class ModelSelectionSheet extends StatefulWidget {
  final String initialSelection;

  const ModelSelectionSheet({super.key, required this.initialSelection});

  @override
  State<ModelSelectionSheet> createState() => _ModelSelectionSheetState();
}

class _ModelSelectionSheetState extends State<ModelSelectionSheet> {
  late String _selectedModel;
  
  // The 33 models for the Text bar
  static final List<AiModel> _defaultTextModels = [
    AiModel('ILMU Mini v3.3', 'Provider: ILMU', false, Icons.auto_awesome),
    AiModel('GLM OCR', 'Provider: GLM', false, Icons.document_scanner),
    AiModel('Deepseek V4 Flash', 'Provider: DeepSeek', false, Icons.auto_awesome),
    AiModel('Qwen 3 VL Flash', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Seed 2.0 mini', 'Provider: ByteDance', false, Icons.auto_awesome),
    AiModel('Hunyuan 3', 'Provider: Tencent', false, Icons.auto_awesome),
    AiModel('Qwen 3.7 Flash', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Gemini 3.1 Flash Lite', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Qwen 3.6 Flash', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Deepseek v3.2', 'Provider: DeepSeek', false, Icons.auto_awesome),
    AiModel('ILMU Vision v1.3', 'Provider: ILMU', false, Icons.auto_awesome),
    AiModel('Gemini 3.5 Flash Lite', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Qwen 3 VL Plus', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Qwen 3.5 Plus', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('GLM 4.7', 'Provider: GLM', false, Icons.auto_awesome),
    AiModel('Qwen 3.6 27B', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Seed 1.8', 'Provider: ByteDance', false, Icons.auto_awesome),
    AiModel('Gemini 3 Flash', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('GLM 5', 'Provider: GLM', false, Icons.auto_awesome),
    AiModel('Deepseek V4 Pro', 'Provider: DeepSeek', false, Icons.auto_awesome),
    AiModel('ILMU v3.1', 'Provider: ILMU', false, Icons.auto_awesome),
    AiModel('Qwen 3.6 Plus', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('GLM 5.2', 'Provider: GLM', false, Icons.auto_awesome),
    AiModel('GLM 5 Turbo', 'Provider: GLM', false, Icons.auto_awesome),
    AiModel('GLM 5.1', 'Provider: GLM', false, Icons.auto_awesome),
    AiModel('Qwen 3.7 Plus', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Gemini 3.6 Flash', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Gemini 3.5 Flash', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Qwen 3.6 Max', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Gemini 2.5 Pro', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Qwen 3.7 Max', 'Provider: Qwen', false, Icons.auto_awesome),
    AiModel('Gemini 3.1 pro', 'Provider: Google', false, Icons.auto_awesome),
    AiModel('Kimi K3', 'Provider: Moonshot', false, Icons.auto_awesome),
  ];

  List<AiModel> _models = List.from(_defaultTextModels);
  bool _isLoading = false;
  String _selectedCategory = 'Text'; // Default category tab: Text | Image | Video

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.initialSelection;
    _fetchModelsFromBackend();
  }

  // Fetch model list from FastAPI backend to sync with database
  Future<void> _fetchModelsFromBackend() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.modelsEndpoint));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> backendModels = data['models'] ?? [];

        if (!mounted || backendModels.isEmpty) return;
        setState(() {
          _models = backendModels
              .map((item) {
                final name = item['name'] ?? 'Unknown Model';
                return AiModel(
                  name,
                  'Provider: ${item['provider'] ?? 'Unknown'}',
                  false,
                  name == 'GLM OCR' ? Icons.document_scanner : Icons.auto_awesome,
                );
              })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Keep default models if offline
    }
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEF7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              title: 'Text',
              iconWidget: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFFFF4081), Color(0xFFFFD600)],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              title: 'Image',
              iconWidget: const Icon(
                Icons.image_outlined,
                size: 16,
                color: Color(0xFFFF6D00),
              ),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              title: 'Video',
              iconWidget: const Icon(
                Icons.play_circle_outline,
                size: 16,
                color: Color(0xFFD500F9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({required String title, required Widget iconWidget}) {
    final bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF8B2FC9), Color(0xFF6A0DAD)],
                )
              : null,
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x598A2BE2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
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
          const SizedBox(height: 16),

          // Segmented Bar: Text | Image | Video
          _buildCategoryTabs(),
          const SizedBox(height: 20),

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

          // Grid of models or placeholder
          Expanded(
            child: _selectedCategory != 'Text'
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedCategory == 'Image'
                              ? Icons.image_outlined
                              : Icons.play_circle_outline,
                          size: 54,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_selectedCategory Models',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Coming soon on Grafilab platform',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isLoading
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
                            child: Container(
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
                                      Icon(model.icon, size: 20, color: Colors.black87),
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
                                    child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
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
