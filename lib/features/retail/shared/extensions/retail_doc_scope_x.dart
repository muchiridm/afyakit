// lib/features/retail/shared/extensions/retail_doc_scope_x.dart

enum RetailDocScope { all, mine }

extension RetailDocScopeX on RetailDocScope {
  bool get isMine => this == RetailDocScope.mine;

  String titleSuffix(String base) => isMine ? 'My $base' : base;
}
