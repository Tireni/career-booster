import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: const Icon(Icons.auto_awesome),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _register ? 'Start your next chapter.' : 'Welcome back.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register
                          ? 'Create an account to get started.'
                          : 'Sign in to your Career Booster account.',
                    ),
                    const SizedBox(height: 28),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        enabled: !vm.busy,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter your full name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        enabled: !vm.busy,
                        maxLength: 254,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch((v ?? '').trim())
                            ? 'Enter a valid email.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _username,
                      enabled: !vm.busy,
                      maxLength: _register ? 32 : 254,
                      decoration: InputDecoration(
                        labelText: _register ? 'Username' : 'Email or username',
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) {
                          return 'Enter your ${_register ? 'username' : 'email or username'}.';
                        }
                        if (_register &&
                            (value.length < 3 ||
                                !RegExp(r'^[A-Za-z0-9_.-]+$')
                                    .hasMatch(value))) {
                          return 'Use at least 3 letters, numbers, dots, dashes or underscores.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !vm.busy,
                      obscureText: !_showPassword,
                      maxLength: 128,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < (_register ? 8 : 1)
                          ? (_register
                                ? 'Use at least 8 characters.'
                                : 'Enter your password.')
                          : null,
                    ),
                    if (vm.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          vm.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: vm.busy
                            ? null
                            : () {
                                if (_form.currentState!.validate()) {
                                  vm.submit(
                                    register: _register,
                                    fullName: _name.text,
                                    email: _email.text,
                                    username: _username.text,
                                    password: _password.text,
                                  );
                                }
                              },
                        child: Text(
                          vm.busy
                              ? 'Please wait...'
                              : _register
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: vm.busy
                            ? null
                            : () {
                                setState(() => _register = !_register);
                                vm.clearError();
                              },
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
