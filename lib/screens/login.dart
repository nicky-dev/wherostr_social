import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wherostr_social/models/app_states.dart';
import 'package:wherostr_social/utils/app_utils.dart';
import 'package:wherostr_social/widgets/themed_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final GlobalKey<FormFieldState<String>> _nsecFormFieldKey =
      GlobalKey<FormFieldState<String>>();
  final TextEditingController _loginController = TextEditingController();
  bool _obscurePivateKey = true;

  @override
  void dispose() {
    _loginController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.read<AppStatesProvider>();
    ThemeData themeData = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: wherostrBackgroundDecoration,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        const ThemedLogo(height: 120),
                        const SizedBox(height: 16),
                        Text(
                          'New to Nostr?',
                          style: themeData.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: () async {
                            context.push('/create-account');
                          },
                          child: const Text('Create account'),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Have an account?',
                          style: themeData.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          key: _nsecFormFieldKey,
                          controller: _loginController,
                          decoration: InputDecoration(
                            filled: true,
                            hintText: 'Your private key (nsec)',
                            suffix: IconButton(
                              icon: Icon(_obscurePivateKey
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () => setState(() {
                                _obscurePivateKey = !_obscurePivateKey;
                              }),
                            ),
                          ),
                          obscureText: _obscurePivateKey,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            if (appState.verifyNsec(value) ||
                                appState.verifyNpub(value)) return null;
                            return 'Invalid private key';
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: () async {
                            if (_nsecFormFieldKey.currentState?.validate() !=
                                true) {
                              return;
                            }
                            bool isLoggedId =
                                await appState.login(_loginController.text);
                            if (!isLoggedId) return;
                            context.go('/');
                          },
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 1,
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          context.push('/app-relay-settings');
                        },
                        label: const Text('Choose app relays'),
                        icon: const Icon(Icons.hub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
