import 'package:flutter/material.dart';

import 'package:dranyen/features/learn/learn_content.dart';

const _amber = Color(0xFFF0A93C);
const _ink = Color(0xFFE8EAED);
const _body = Color(0xFFC4C8D0);
const _muted = Color(0xFF9AA0AB);

class LearnArticlePage extends StatelessWidget {
  final Article article;
  const LearnArticlePage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [for (final b in article.blocks) _block(b)],
      ),
    );
  }

  Widget _block(Block b) {
    return switch (b) {
      H(:final text) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(text, style: const TextStyle(color: _amber, fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      P(:final text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text, style: const TextStyle(color: _body, fontSize: 15.5, height: 1.55)),
        ),
      Bul(:final items) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7, right: 10),
                        child: Icon(Icons.circle, size: 5, color: _amber),
                      ),
                      Expanded(child: Text(it, style: const TextStyle(color: _body, fontSize: 15, height: 1.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      Quote(:final text, :final attribution) => Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _amber.withValues(alpha: 0.6), width: 3)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(color: _ink, fontSize: 16, height: 1.6, fontStyle: FontStyle.italic)),
              if (attribution != null) ...[
                const SizedBox(height: 8),
                Text('— $attribution', style: const TextStyle(color: _muted, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      Tbl(:final headers, :final rows) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 50,
              columnSpacing: 22,
              headingTextStyle: const TextStyle(color: _amber, fontSize: 13, fontWeight: FontWeight.w600),
              dataTextStyle: const TextStyle(color: _body, fontSize: 13.5),
              columns: [for (final h in headers) DataColumn(label: Text(h))],
              rows: [
                for (final r in rows)
                  DataRow(cells: [for (final c in r) DataCell(Text(c))]),
              ],
            ),
          ),
        ),
      Note(:final text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Text(text, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.5)),
        ),
    };
  }
}
