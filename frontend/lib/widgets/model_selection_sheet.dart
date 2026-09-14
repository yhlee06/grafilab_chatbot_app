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

  // Default models matching the exact PostgreSQL models table
  static final List<AiModel> _defaultTextModels = [
    AiModel('ILMU Mini v3.3', 'Provider: ILMU', false, Icons.auto_awesome, modelUrl: 'ilmu/ilmu-mini-v3.3'),
    AiModel('GLM OCR', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'grafilab/glm-ocr'),
    AiModel('Deepseek V4 Flash', 'Provider: DeepSeek', false, Icons.auto_awesome, modelUrl: 'deepseek/deepseek-v4-flash'),
    AiModel('Qwen 3 VL Flash', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3-vl-flash'),
    AiModel('Seed 2.0 mini', 'Provider: ByteDance', false, Icons.auto_awesome, modelUrl: 'byteplus/seed-2-0-mini-260215'),
    AiModel('Hunyuan 3', 'Provider: Tencent', false, Icons.auto_awesome, modelUrl: 'tencent/hy3'),
    AiModel('Qwen 3.7 Flash', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.7-flash'),
    AiModel('Gemini 3.1 Flash Lite', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3.1-flash-lite-preview'),
    AiModel('Qwen 3.6 Flash', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.6-flash'),
    AiModel('Deepseek v3.2', 'Provider: DeepSeek', false, Icons.auto_awesome, modelUrl: 'deepseek/deepseek-v3.2'),
    AiModel('ILMU Vision v1.3', 'Provider: ILMU', false, Icons.auto_awesome, modelUrl: 'ilmu/ilmu-vision-v1.3'),
    AiModel('Gemini 3.5 Flash Lite', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3.5-flash-lite'),
    AiModel('Qwen 3 VL Plus', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3-vl-plus'),
    AiModel('Qwen 3.5 Plus', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.5-plus'),
    AiModel('GLM 4.7', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'z-ai/glm-4.7'),
    AiModel('Qwen 3.6 27B', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.6-27b'),
    AiModel('Seed 1.8', 'Provider: ByteDance', false, Icons.auto_awesome, modelUrl: 'byteplus/seed-1-8-251228'),
    AiModel('Gemini 3 Flash', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3-flash'),
    AiModel('GLM 5', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'z-ai/glm-5'),
    AiModel('Deepseek V4 Pro', 'Provider: DeepSeek', false, Icons.auto_awesome, modelUrl: 'deepseek/deepseek-v4-pro'),
    AiModel('ILMU v3.1', 'Provider: ILMU', false, Icons.auto_awesome, modelUrl: 'ilmu/ilmu-v3.1'),
    AiModel('Qwen 3.6 Plus', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.6-plus'),
    AiModel('GLM 5.2', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'z-ai/glm-5.2'),
    AiModel('GLM 5 Turbo', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'z-ai/glm-5-turbo'),
    AiModel('GLM 5.1', 'Provider: GLM', false, Icons.auto_awesome, modelUrl: 'z-ai/glm-5.1'),
    AiModel('Qwen 3.7 Plus', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.7-plus'),
    AiModel('Gemini 3.6 Flash', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3.6-flash'),
    AiModel('Gemini 3.5 Flash', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3.5-flash'),
    AiModel('Qwen 3.6 Max', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.6-max'),
    AiModel('Gemini 2.5 Pro', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-2.5-pro'),
    AiModel('Qwen 3.7 Max', 'Provider: Qwen', false, Icons.auto_awesome, modelUrl: 'qwen/qwen3.7-max'),
    AiModel('Gemini 3.1 pro', 'Provider: Google', false, Icons.auto_awesome, modelUrl: 'gemini/gemini-3.1-pro-preview'),
    AiModel('Kimi K3', 'Provider: Moonshot', false, Icons.auto_awesome, modelUrl: 'moonshot/kimi-k3'),
  ];

  late List<AiModel> _models;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.initialSelection;
    _models = List.from(_defaultTextModels);
    _fetchModelsFromBackend();
  }

  // Fetch model list from FastAPI backend to sync with database
  Future<void> _fetchModelsFromBackend() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.modelsEndpoint))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> backendModels = data['models'] ?? [];

        if (!mounted || backendModels.isEmpty) return;
        setState(() {
          _models = backendModels
              .map((item) {
                return AiModel(
                  item['name'] ?? 'Unknown Model',
                  'Provider: ${item['provider'] ?? 'Unknown'}',
                  false,
                  Icons.auto_awesome,
                  modelUrl: item['model_url'],
                );
              })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Keep default models if backend is unreachable
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
                          final isSelected = model.name == _selectedModel ||
                              (model.modelUrl != null && model.modelUrl == _selectedModel);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
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
                final chosen = _models.firstWhere(
                  (m) => m.name == _selectedModel || m.modelUrl == _selectedModel,
                  orElse: () => AiModel(_selectedModel, '', false, Icons.auto_awesome),
                );
                Navigator.pop(context, chosen);
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
