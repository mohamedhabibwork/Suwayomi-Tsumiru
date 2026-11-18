import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:graphql/client.dart';
import 'package:material_ui/material_ui.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../../../utils/network/graphql_errors.dart';

enum AccountCodeMode { registration, recovery }

class AccountCodeDialog extends HookWidget {
  const AccountCodeDialog({
    super.key,
    required this.mode,
    required this.onSubmit,
  });

  final AccountCodeMode mode;
  final Future<void> Function({
    required String code,
    String? username,
    required String password,
  })
  onSubmit;

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final password = useTextEditingController();
    final confirmation = useTextEditingController();
    final busy = useState(false);
    final error = useState<String?>(null);
    final code = useTextEditingController();
    final username = useTextEditingController();
    final registration = mode == AccountCodeMode.registration;
    final title = registration
        ? context.l10n.accountRegistrationTitle
        : context.l10n.accountRecoveryTitle;

    Future<void> submit() async {
      if (busy.value || !(formKey.currentState?.validate() ?? false)) return;
      busy.value = true;
      error.value = null;
      try {
        await onSubmit(
          code: code.text.trim(),
          username: registration ? username.text.trim() : null,
          password: password.text,
        );
        TextInput.finishAutofillContext(shouldSave: true);
        if (context.mounted) Navigator.pop(context);
      } catch (failure) {
        if (!context.mounted) return;
        final cause = failure is OperationMessageException
            ? failure.exception
            : failure;
        final message = cause is OperationException
            ? OperationMessageException(cause).toString()
            : cause.toString();
        error.value = isConnectionError(cause)
            ? context.l10n.authTestConnectionFailedNetwork
            : isPermissionDenied(cause)
            ? context.l10n.accountPermissionDenied
            : message.trim().isEmpty
            ? context.l10n.errorSomethingWentWrong
            : message;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return PopScope(
      canPop: !busy.value,
      child: AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Form(
          key: formKey,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!registration) ...[
                  TextFormField(
                    controller: code,
                    enabled: !busy.value,
                    obscureText: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.l10n.accountRecoveryCode,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.accountCodeRequired
                        : null,
                  ),
                  const Gap(8),
                ],
                if (registration) ...[
                  TextFormField(
                    controller: username,
                    enabled: !busy.value,
                    obscureText: false,
                    autocorrect: false,
                    enableSuggestions: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.newUsername,
                      AutofillHints.username,
                    ],
                    decoration: InputDecoration(
                      labelText: context.l10n.userName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.errorUserName
                        : null,
                  ),
                  const Gap(8),
                ],
                TextFormField(
                  controller: password,
                  enabled: !busy.value,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.newPassword,
                    AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: context.l10n.accountNewPassword,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? context.l10n.errorPassword
                      : null,
                ),
                const Gap(8),
                TextFormField(
                  controller: confirmation,
                  enabled: !busy.value,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: registration
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: const [
                    AutofillHints.newPassword,
                    AutofillHints.password,
                  ],
                  onFieldSubmitted: registration ? null : (_) => submit(),
                  decoration: InputDecoration(
                    labelText: context.l10n.accountConfirmPassword,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? context.l10n.errorPassword
                      : value != password.text
                      ? context.l10n.accountPasswordsDoNotMatch
                      : null,
                ),
                if (registration) ...[
                  const Gap(8),
                  TextFormField(
                    controller: code,
                    enabled: !busy.value,
                    obscureText: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: context.l10n.accountRegistrationCode,
                      helperText:
                          'Optional — leave blank for open registration',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const Gap(8),
                if (error.value != null)
                  SelectableText(
                    error.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (busy.value) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy.value ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: busy.value ? null : submit,
            child: Text(title),
          ),
        ],
      ),
    );
  }
}
