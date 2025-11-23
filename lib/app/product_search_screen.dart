// Product search UI removed.
//
// The home (shopper) dashboard now contains the main search controls.
// This file is kept as a lightweight placeholder to avoid accidental
// imports elsewhere — prefer using the home screen search instead.

import 'package:flutter/material.dart';

class ProductSearchScreenRemoved extends StatelessWidget {
  const ProductSearchScreenRemoved({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Removed')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'The dedicated product search screen has been removed. Use the search bar on the home screen instead.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
