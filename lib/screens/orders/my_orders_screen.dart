import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  // دالة لجلب الطلبات الخاصة بالمستخدم الحالي فقط
  Future<List<Map<String, dynamic>>> _fetchMyOrders() {
    final userId = supabase.auth.currentUser!.id;
    return supabase
        .from('orders')
        .select()
        .eq('user_id', userId) // جلب الطلبات المطابقة للـ ID الخاص بي
        .order('created_at', ascending: false); // عرض الأحدث أولاً
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي السابقة'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            //print('--- MY ORDERS ERROR: ${snapshot.error} ---');
            return const Center(child: Text('خطأ في جلب الطلبات'));
          }

          final orders = snapshot.data;
          if (orders == null || orders.isEmpty) {
            return const Center(
              child: Text('لا يوجد لديك طلبات سابقة.', style: TextStyle(fontSize: 18)),
            );
          }

          // عرض الطلبات في قائمة
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final cartItems = order['cart_items'] as Map<String, dynamic>;
              // حساب عدد المنتجات في هذا الطلب
              final int totalItems = cartItems.values.fold(0, (sum, item) => sum + (item as int));

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('طلب بتاريخ: ${DateTime.parse(order['created_at']).toLocal().toString().substring(0, 16)}'),
                  subtitle: Text('العنوان: ${order['customer_address']}\nالحالة: ${order['status']}'),
                  trailing: Text('عدد المنتجات: $totalItems', style: const TextStyle(fontWeight: FontWeight.bold)),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}