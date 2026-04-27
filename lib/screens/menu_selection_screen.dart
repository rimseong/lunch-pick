import 'package:flutter/material.dart';
import 'dart:io';
import '../models/session.dart';
import '../models/member.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class MenuSelectionScreen extends StatefulWidget {
  final Session session;
  final int? currentUserId;
  const MenuSelectionScreen({super.key, required this.session, this.currentUserId});

  @override
  State<MenuSelectionScreen> createState() => _MenuSelectionScreenState();
}

class _MenuSelectionScreenState extends State<MenuSelectionScreen> {
  Member? _selectedMember;
  String? _selectedMenuItemId; // 투표 완료 전까지 로컬에만 보관
  final List<MenuItem> _addedMenuItems = [];
  final Set<String> _deletedMenuItemIds = {};
  final Map<String, int> _priceOverrides = {};

  @override
  void initState() {
    super.initState();
    final members = widget.session.members;
    if (members.isEmpty) return;
    // currentUserId가 있으면 해당 멤버를 찾아 초기 선택, 없으면 마지막 멤버
    if (widget.currentUserId != null) {
      try {
        _selectedMember = members.firstWhere(
          (m) => m.serverId == widget.currentUserId,
        );
      } catch (_) {
        _selectedMember = members.last;
      }
    } else {
      _selectedMember = members.last;
    }
    _selectedMenuItemId = _selectedMember?.selectedMenuItemId;
  }

  bool _isSubmitting = false;

  List<MenuItem> get _allMenuItems {
    final restaurant = widget.session.selectedRestaurant;
    final base = restaurant?.menuItems ?? [];
    return [...base, ..._addedMenuItems]
        .where((m) => !_deletedMenuItemIds.contains(m.id))
        .toList();
  }

  bool get _canSubmit =>
      _selectedMenuItemId != null &&
      !_deletedMenuItemIds.contains(_selectedMenuItemId);

  int _priceOf(MenuItem item) => _priceOverrides[item.id] ?? item.price;

  int _selectedPrice() {
    if (_selectedMenuItemId == null) return 0;
    try {
      final item = _allMenuItems.firstWhere((m) => m.id == _selectedMenuItemId);
      return _priceOf(item);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _showEditPriceDialog(MenuItem item) async {
    final ctrl = TextEditingController(text: _priceOf(item).toString());
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(item.name),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '가격 (원)',
                suffixText: '원',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '가격을 입력하세요';
                if (int.tryParse(v.trim()) == null) return '숫자만 입력하세요';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final newPrice = int.parse(ctrl.text.trim());
                      setDialogState(() => isSaving = true);

                      if (item.serverId != null && widget.session.selectedRestaurant?.serverId != null) {
                        try {
                          await ApiService.updateMenuPrice(
                            menuId: item.serverId!,
                            restaurantId: widget.session.selectedRestaurant!.serverId!,
                            name: item.name,
                            price: newPrice,
                          );
                        } catch (_) {
                          // 서버 실패 시 로컬에만 반영
                        }
                      }

                      if (mounted) setState(() => _priceOverrides[item.id] = newPrice);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('수정', style: TextStyle(color: Color(0xFFFF6B35))),
            ),
          ],
        );
      }),
    );
  }

  void _selectMenu(MenuItem item) {
    if (_selectedMember == null) return;
    setState(() {
      _selectedMenuItemId = _selectedMenuItemId == item.id ? null : item.id;
    });
  }

  Future<void> _showAddMenuDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('메뉴 직접 추가',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '메뉴 이름',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '메뉴 이름을 입력하세요' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '가격 (원)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '가격을 입력하세요';
                      if (int.tryParse(v.trim()) == null) return '숫자만 입력하세요';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);

                              final name = nameCtrl.text.trim();
                              final price = int.parse(priceCtrl.text.trim());
                              final restaurant = widget.session.selectedRestaurant;
                              final restaurantServerId = restaurant?.serverId;

                              int? menuServerId;
                              try {
                                if (restaurantServerId != null) {
                                  final result = await ApiService.createMenu(
                                    restaurantId: restaurantServerId,
                                    name: name,
                                    price: price,
                                  );
                                  menuServerId = result['id'] as int?;
                                }
                              } catch (_) {
                                // 서버 저장 실패 시 로컬에만 추가
                              }

                              final newItem = MenuItem(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: name,
                                price: price,
                                serverId: menuServerId,
                              );

                              if (mounted) {
                                setState(() => _addedMenuItems.add(newItem));
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _showDeleteMenuDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final items = _allMenuItems;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('메뉴 삭제',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '삭제할 메뉴를 선택하세요',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('삭제할 메뉴가 없어요',
                          style: TextStyle(color: Colors.grey[400])),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          title: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: item.price > 0
                              ? Text('${formatPrice(item.price)}원',
                                  style: const TextStyle(
                                      color: Color(0xFFFF6B35), fontSize: 13))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  title: const Text('메뉴 삭제'),
                                  content:
                                      Text('"${item.name}"을(를) 삭제할까요?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('삭제',
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              // 서버 삭제 시도
                              if (item.serverId != null) {
                                try {
                                  await ApiService.deleteMenu(item.serverId!);
                                } catch (_) {
                                  // 서버 실패해도 로컬에서는 제거
                                }
                              }

                              if (mounted) {
                                setState(() {
                                  _deletedMenuItemIds.add(item.id);
                                  _addedMenuItems.remove(item);
                                  // 해당 메뉴를 선택한 멤버 선택 초기화
                                  for (final m in widget.session.members) {
                                    if (m.selectedMenuItemId == item.id) {
                                      m.selectedMenuItemId = null;
                                    }
                                  }
                                  if (_selectedMenuItemId == item.id) {
                                    _selectedMenuItemId = null;
                                  }
                                });
                                setModalState(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _goToResult() async {
    if (_selectedMember == null) return;

    // 투표 완료 시점에 로컬 선택을 멤버에 반영
    _selectedMember!.selectedMenuItemId = _selectedMenuItemId;

    final restaurant = widget.session.selectedRestaurant;
    final menuItem = _allMenuItems.cast<MenuItem?>().firstWhere(
      (m) => m?.id == _selectedMenuItemId,
      orElse: () => null,
    );
    final userId = _selectedMember!.serverId;
    final restaurantServerId = restaurant?.serverId;
    final menuServerId = menuItem?.serverId;

    if (userId != null && restaurantServerId != null && menuServerId != null && menuItem != null) {
      setState(() => _isSubmitting = true);
      try {
        final result = await ApiService.createSelection(
          userId: userId,
          restaurantId: restaurantServerId,
          menuId: menuServerId,
          price: _priceOf(menuItem),
        );
        _selectedMember!.selectionServerId = result['id'] as int?;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 오류: $e')),
        );
        setState(() => _isSubmitting = false);
        return;
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final restaurant = session.selectedRestaurant;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          restaurant?.name ?? '메뉴 선택',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Column(
        children: [
          // 선정된 식당 배너
          Container(
            color: const Color(0xFFFF6B35),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '투표로 선정된 식당: ${restaurant?.name ?? ''}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 멤버 선택
                  const Text(
                    '메뉴를 선택할 멤버',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.members.map((member) {
                      final isMe = member.serverId == widget.currentUserId;
                      final isSelected = _selectedMember?.id == member.id;
                      final hasPicked = member.selectedMenuItemId != null;
                      return GestureDetector(
                        onTap: isMe ? () => setState(() => _selectedMember = member) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6B35)
                                : isMe ? Colors.white : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B35)
                                  : isMe ? Colors.grey[300]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                member.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isMe ? Colors.black87 : Colors.grey[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasPicked) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFFF6B35),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 메뉴 목록
                  const Text(
                    '메뉴',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_allMenuItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '등록된 메뉴가 없어요',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  else
                    ..._allMenuItems.map((item) {
                      final isItemSelected = _selectedMenuItemId == item.id;
                      final isAdded = _addedMenuItems.contains(item);
                      return GestureDetector(
                        onTap: _selectedMember != null
                            ? () => _selectMenu(item)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isItemSelected
                                  ? const Color(0xFFFF6B35)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isItemSelected)
                                const Icon(Icons.check_circle,
                                    color: Color(0xFFFF6B35), size: 20)
                              else
                                const Icon(Icons.radio_button_unchecked,
                                    color: Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              if (item.imagePath != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(item.imagePath!),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        if (isAdded) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '직접 추가',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFFFF6B35),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item.description != null)
                                      Text(
                                        item.description!,
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _priceOf(item) > 0 ? '${formatPrice(_priceOf(item))}원' : '',
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B35),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showEditPriceDialog(item),
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _showAddMenuDialog,
                        icon: const Icon(Icons.add_circle_outline,
                            color: Color(0xFFFF6B35), size: 18),
                        label: const Text(
                          '메뉴 직접 추가',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _showDeleteMenuDialog,
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 18),
                        label: const Text(
                          '메뉴 삭제',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Text(
                        '총 금액',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        _selectedMenuItemId != null
                            ? '${formatPrice(_selectedPrice())}원'
                            : '-',
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isSubmitting) ? _goToResult : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '투표 완료',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
        ],
      ),
    );
  }
}
