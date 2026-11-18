import 'dart:async';

import 'package:graphql/client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../global_providers/global_providers.dart';
import '../../../../graphql/__generated__/schema.graphql.dart';
import '../../../../utils/analytics/firebase_telemetry_service.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../account/data/account_permission.dart';
import '../../domain/extension/top_extensions.dart';
import '../../domain/extension_store/extension_store_model.dart';
import 'graphql/__generated__/query.graphql.dart';

part 'extension_store_repository.g.dart';

class ExtensionStoreRepository {
  const ExtensionStoreRepository(this.client, {required this.permissions});

  final AccountPermissionGuard permissions;
  final GraphQLClient client;

  Future<({List<ExtensionStore> stores, int totalCount})?>
  getExtensionStores() async {
    final raw = await client
        .query$ExtensionStoreList(
          Options$Query$ExtensionStoreList(fetchPolicy: FetchPolicy.networkOnly),
        )
        .getData(
          (data) => (
            stores: data.extensionStores.nodes.toList(),
            totalCount: data.extensionStores.totalCount,
          ),
        );
    if (raw == null) return null;

    final seenUrls = <String>{};
    final seenNames = <String>{};
    final uniqueStores = <ExtensionStore>[];
    final toPrune = <String>[];

    // Sort so canonical URLs come before legacy duplicate mirrors.
    final sorted = [...raw.stores]
      ..sort((a, b) {
        final aDup = isRedundantDuplicateStoreUrl(a.indexUrl);
        final bDup = isRedundantDuplicateStoreUrl(b.indexUrl);
        if (aDup != bDup) return aDup ? 1 : -1;
        return 0;
      });

    for (final store in sorted) {
      final normUrl = normalizeExtensionStoreUrl(store.indexUrl);
      final normName = store.name.trim().toLowerCase();
      if (isRedundantDuplicateStoreUrl(store.indexUrl) ||
          !seenUrls.add(normUrl) ||
          (normName.isNotEmpty && !seenNames.add(normName))) {
        toPrune.add(store.indexUrl);
        continue;
      }
      uniqueStores.add(store);
    }

    if (toPrune.isNotEmpty) {
      unawaited(
        Future(() async {
          for (final dupUrl in toPrune) {
            try {
              await removeStore(dupUrl);
            } catch (_) {}
          }
        }),
      );
    }

    return (stores: uniqueStores, totalCount: uniqueStores.length);
  }

  Future<void> addStore(String indexUrl) {
    AppTelemetry.logExtensionStoreAction(action: 'add', indexUrl: indexUrl);
    return permissions.run(
      Enum$UserPermission.MANAGE_EXTENSION_STORES,
      () => client
          .mutate$AddExtensionStore(
            Options$Mutation$AddExtensionStore(
              variables: Variables$Mutation$AddExtensionStore(
                indexUrl: indexUrl,
              ),
            ),
          )
          .getData((data) {}),
    );
  }

  Future<void> removeStore(String indexUrl) {
    AppTelemetry.logExtensionStoreAction(action: 'remove', indexUrl: indexUrl);
    return permissions.run(
      Enum$UserPermission.MANAGE_EXTENSION_STORES,
      () => client
          .mutate$RemoveExtensionStore(
            Options$Mutation$RemoveExtensionStore(
              variables: Variables$Mutation$RemoveExtensionStore(
                indexUrl: indexUrl,
              ),
            ),
          )
          .getData((data) {}),
    );
  }
}

@riverpod
ExtensionStoreRepository extensionStoreRepository(Ref ref) =>
    ExtensionStoreRepository(
      ref.watch(graphQlClientProvider),
      permissions: ref.watch(accountPermissionGuardProvider),
    );

@riverpod
Future<({List<ExtensionStore> stores, int totalCount})?> extensionStoreList(
  Ref ref,
) {
  final result = ref
      .watch(extensionStoreRepositoryProvider)
      .getExtensionStores();
  ref.keepAlive();
  return result;
}
