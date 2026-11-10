/// 画面で共通に使う見た目の部品。
library;

import 'package:flutter/material.dart';

import 'models.dart';

/// ジャンルに選べるアイコン。キーで保存する。
const genreIcons = <String, IconData>{
  'cooking': Icons.restaurant,
  'shopping': Icons.shopping_cart,
  'laundry': Icons.local_laundry_service,
  'cleaning': Icons.cleaning_services,
  'pet': Icons.pets,
  'childcare': Icons.child_care,
  'education': Icons.school,
  'other': Icons.more_horiz,
  'home': Icons.home,
  'car': Icons.directions_car,
  'garden': Icons.yard,
  'money': Icons.payments,
  'health': Icons.medical_services,
  'trash': Icons.delete_outline,
  'event': Icons.event,
  'star': Icons.star_outline,
};

/// ジャンルやメンバーに選べる色。
const paletteColors = <int>[
  0xFF4E79A7,
  0xFFF28E2B,
  0xFFE15759,
  0xFF76B7B2,
  0xFF59A14F,
  0xFFEDC948,
  0xFFB07AA1,
  0xFFFF9DA7,
  0xFF9C755F,
  0xFF6A5ACD,
  0xFF8C8C8C,
];

IconData iconFor(Genre g) => genreIcons[g.iconKey] ?? Icons.label_outline;

/// ジャンルの丸アイコン。
class GenreBadge extends StatelessWidget {
  const GenreBadge(this.genre, {super.key, this.size = 36});
  final Genre genre;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(genre.colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconFor(genre), color: color, size: size * 0.55),
    );
  }
}

/// メンバーの頭文字アイコン。
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.radius = 12});
  final Member? member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final m = member;
    if (m == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.groups, size: radius * 1.2, color: Colors.grey.shade700),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(m.colorValue),
      child: Text(
        m.name.isEmpty ? '?' : m.name.characters.first,
        style: TextStyle(color: Colors.white, fontSize: radius * 0.9),
      ),
    );
  }
}

/// 名前を入力するだけの小さなダイアログ。
Future<String?> askText(BuildContext context,
    {required String title, String initial = '', String hint = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
