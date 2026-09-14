import 'package:flutter/material.dart';

class AiModel {
  final String name;
  final String description;
  final bool isPro;
  final IconData icon;
  final String? modelUrl;

  AiModel(
    this.name,
    this.description,
    this.isPro,
    this.icon, {
    this.modelUrl,
  });
}
