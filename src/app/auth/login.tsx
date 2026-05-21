import React, { useState } from 'react';
import { View, Text, StyleSheet, KeyboardAvoidingView, Platform, ScrollView, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import * as SecureStore from 'expo-secure-store';
import { GlassCard } from '../../components/GlassCard';
import { InputField } from '../../components/InputField';
import { CustomButton } from '../../components/CustomButton';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function LoginScreen() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Please enter both email and password.');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post('/auth/login', { email: email.toLowerCase(), password });
      if (res.data?.token) {
        await SecureStore.setItemAsync('userToken', res.data.token);
        if (res.data?.userId) {
           await SecureStore.setItemAsync('userId', res.data.userId.toString());
        }
        router.replace('/(tabs)');
      } else {
        Alert.alert('Error', 'Invalid login response');
      }
    } catch (error: any) {
      const msg = error.response?.data?.MESSAGE || error.response?.data?.message || error.message || 'Login failed';
      Alert.alert('Error', msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <Text style={styles.title}>Welcome back</Text>
          <Text style={styles.subtitle}>Sign in to access your print jobs</Text>
        </View>

        <GlassCard intensity={30} style={styles.card}>
          <InputField
            label="College Email"
            icon="mail-outline"
            placeholder="student@amrita.edu"
            keyboardType="email-address"
            autoCapitalize="none"
            value={email}
            onChangeText={setEmail}
          />
          <InputField
            label="Password"
            icon="lock-closed-outline"
            placeholder="••••••••"
            secureTextEntry
            value={password}
            onChangeText={setPassword}
          />
          
          <CustomButton title="Sign In" onPress={handleLogin} loading={loading} />
          <CustomButton title="Forgot Password?" variant="ghost" onPress={() => {}} />
        </GlassCard>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Don't have an account?</Text>
          <CustomButton 
            title="Create Member Account" 
            variant="outline" 
            onPress={() => router.push('/auth/signup')} 
          />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    flexGrow: 1,
    padding: 24,
    justifyContent: 'center',
  },
  header: {
    marginBottom: 40,
    marginTop: 60,
  },
  title: {
    fontSize: 32,
    fontWeight: '800',
    color: colors.text,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: colors.textMuted,
  },
  card: {
    marginBottom: 32,
  },
  footer: {
    marginTop: 'auto',
    marginBottom: 32,
  },
  footerText: {
    color: colors.textMuted,
    textAlign: 'center',
    marginBottom: 16,
  },
});
