import 'package:equatable/equatable.dart';

class WelcomeInfo extends Equatable {
  const WelcomeInfo({required this.title, required this.description});
  final String title;
  final String description;

  @override
  List<Object> get props => [title, description];
}
