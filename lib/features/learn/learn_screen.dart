import 'package:flutter/material.dart';

import 'package:dranyen/features/learn/learn_article_page.dart';
import 'package:dranyen/features/learn/learn_content.dart';

const _amber = Color(0xFFF0A93C);
const _muted = Color(0xFF9AA0AB);

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Text(
              'The dranyen — its history, the instrument, its notation and music. Drawn from cited scholarship.',
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ),
          for (final a in learnArticles) _card(context, a),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Article a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => LearnArticlePage(article: a))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(a.icon, color: _amber, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFE8EAED))),
                      const SizedBox(height: 3),
                      Text(a.summary, style: const TextStyle(fontSize: 13, color: _muted, height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
