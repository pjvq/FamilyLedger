import 'transaction_model.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon; // emoji or icon name
  final TransactionType type;
  final bool isPreset;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.isPreset = true,
    this.sortOrder = 0,
  });
}

/// 预设分类
class PresetCategories {
  PresetCategories._();

  static const expense = [
    CategoryModel(id: 'cat_food', name: '餐饮', icon: '🍜', type: TransactionType.expense, sortOrder: 1),
    CategoryModel(id: 'cat_transport', name: '交通', icon: '🚗', type: TransactionType.expense, sortOrder: 2),
    CategoryModel(id: 'cat_shopping', name: '购物', icon: '🛍️', type: TransactionType.expense, sortOrder: 3),
    CategoryModel(id: 'cat_housing', name: '居住', icon: '🏠', type: TransactionType.expense, sortOrder: 4),
    CategoryModel(id: 'cat_entertainment', name: '娱乐', icon: '🎮', type: TransactionType.expense, sortOrder: 5),
    CategoryModel(id: 'cat_medical', name: '医疗', icon: '🏥', type: TransactionType.expense, sortOrder: 6),
    CategoryModel(id: 'cat_education', name: '教育', icon: '📚', type: TransactionType.expense, sortOrder: 7),
    CategoryModel(id: 'cat_telecom', name: '通讯', icon: '📱', type: TransactionType.expense, sortOrder: 8),
    CategoryModel(id: 'cat_social', name: '人情', icon: '🎁', type: TransactionType.expense, sortOrder: 9),
    CategoryModel(id: 'cat_clothing', name: '服饰', icon: '👔', type: TransactionType.expense, sortOrder: 10),
    CategoryModel(id: 'cat_daily', name: '日用', icon: '🧴', type: TransactionType.expense, sortOrder: 11),
    CategoryModel(id: 'cat_travel', name: '旅行', icon: '✈️', type: TransactionType.expense, sortOrder: 12),
    CategoryModel(id: 'cat_pet', name: '宠物', icon: '🐱', type: TransactionType.expense, sortOrder: 13),
    CategoryModel(id: 'cat_other_exp', name: '其他', icon: '📦', type: TransactionType.expense, sortOrder: 14),
  ];

  static const income = [
    CategoryModel(id: 'cat_salary', name: '工资', icon: '💰', type: TransactionType.income, sortOrder: 1),
    CategoryModel(id: 'cat_bonus', name: '奖金', icon: '🏆', type: TransactionType.income, sortOrder: 2),
    CategoryModel(id: 'cat_investment', name: '投资收益', icon: '📈', type: TransactionType.income, sortOrder: 3),
    CategoryModel(id: 'cat_sidejob', name: '兼职', icon: '💼', type: TransactionType.income, sortOrder: 4),
    CategoryModel(id: 'cat_redpacket', name: '红包', icon: '🧧', type: TransactionType.income, sortOrder: 5),
    CategoryModel(id: 'cat_reimburse', name: '报销', icon: '🧾', type: TransactionType.income, sortOrder: 6),
    CategoryModel(id: 'cat_other_inc', name: '其他', icon: '💵', type: TransactionType.income, sortOrder: 7),
  ];

  static List<CategoryModel> get all => [...expense, ...income];
}
