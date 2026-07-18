import 'package:equatable/equatable.dart';

class TemplateInfo extends Equatable {
  const TemplateInfo({required this.title, required this.description});
  final String title;
  final String description;

  @override
  List<Object> get props => [title, description];
}
