import '../models/models.dart';

const List<Product> sampleProducts = [
  Product(id: 'basmati-1121', name: '1121 Basmati Rice', nameAr: 'أرز بسمتي 1121',
      origin: 'Pakistan', description: 'Extra-long grain aged basmati. Fluffy, aromatic and perfect for biryani and pulao.',
      bagKg: 10, pricePerBag: 6.500, minOrderBags: 5, stock: 120),
  Product(id: 'super-kernel', name: 'Super Kernel Basmati', nameAr: 'بسمتي سوبر كيرنل',
      origin: 'Pakistan', description: 'Premium long grain basmati with excellent elongation and a rich aroma.',
      bagKg: 20, pricePerBag: 11.800, minOrderBags: 5, stock: 90),
  Product(id: 'sella-basmati', name: 'Sella Basmati Rice', nameAr: 'بسمتي سيلا',
      origin: 'India', description: 'Parboiled basmati with firm grains that do not break when cooked.',
      bagKg: 25, pricePerBag: 13.250, minOrderBags: 4, stock: 80),
  Product(id: 'long-grain-white', name: 'Long Grain White Rice', nameAr: 'أرز أبيض طويل الحبة',
      origin: 'India', description: 'Everyday long grain white rice for restaurants, canteens and homes.',
      bagKg: 25, pricePerBag: 9.750, minOrderBags: 4, stock: 150),
  Product(id: 'thai-jasmine', name: 'Thai Jasmine Rice', nameAr: 'أرز ياسمين تايلندي',
      origin: 'Thailand', description: 'Fragrant, soft and slightly sticky jasmine rice from Thailand.',
      bagKg: 5, pricePerBag: 3.900, minOrderBags: 10, stock: 15),
  Product(id: 'thai-hom-mali', name: 'Hom Mali Premium', nameAr: 'هوم مالي ممتاز',
      origin: 'Thailand', description: 'Premium Thai Hom Mali, new crop, naturally fragrant.',
      bagKg: 10, pricePerBag: 7.600, minOrderBags: 6, stock: 60),
];

/// Demo account so you can test the admin panel without Firebase.
const AppUser demoAdmin = AppUser(
  id: 'admin',
  name: 'Admin',
  email: 'admin@jatoi.bh',
  passwordHash: 'sha256\$jatoi-demo-admin\$943f8fed1c922910c967eaa8de44e7bd1ea8a5e81be4649bfe08a05069c6a4cf',
  role: 'admin',
);
