import React, { useState } from 'react';
import { View, Text, StyleSheet, KeyboardAvoidingView, Platform, ScrollView, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { GlassCard } from '../../components/GlassCard';
import { InputField } from '../../components/InputField';
import { CustomButton } from '../../components/CustomButton';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function SignupScreen() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [collegeId, setCollegeId] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSignup = async () => {
    if (!name || !email || !password || !collegeId) {
      Alert.alert('Error', 'Please fill all fields');
      return;
    }
    
    // Domain validation
    const lowerEmail = email.toLowerCase();
    if (!lowerEmail.endsWith('amrita.edu')) {
      Alert.alert('Error', 'Email must end with amrita.edu');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post('/users/add', {
        name,
        email: lowerEmail,
        password,
        collegeId,
        phone: '1234567890', // placeholder
        role: 'MEMBER'
      });
      if (res.status === 200 || res.status === 201) {
        Alert.alert('Success', 'Verification code sent to your email.');
        router.push({
          pathname: '/auth/otp',
          params: { email: lowerEmail }
        });
      }
    } catch (err: any) {
      const msg = err.response?.data?.MESSAGE || err.response?.data?.message || err.message || 'Registration failed';
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
          <Text style={styles.title}>Create Account</Text>
          <Text style={styles.subtitle}>Join CampusPrint</Text>
        </View>

        <GlassCard intensity={30} style={styles.card}>
          <InputField
            label="Full Name"
            icon="person-outline"
            placeholder="John Doe"
            value={name}
            onChangeText={setName}
          />
          <InputField
            label="College ID (e.g. CB.EN.U4...)"
            icon="card-outline"
            placeholder="CB.EN.U4..."
            autoCapitalize="characters"
            value={collegeId}
            onChangeText={setCollegeId}
          />
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
          <CustomButton title="Continue to OTP" onPress={handleSignup} loading={loading} />
        </GlassCard>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Already have an account?</Text>
          <CustomButton title="Sign In" variant="outline" onPress={() => router.back()} />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  scrollContent: { flexGrow: 1, padding: 24, paddingTop: 60, paddingBottom: 40 },
  header: { marginBottom: 32 },
  title: { fontSize: 32, fontWeight: '800', color: colors.text, marginBottom: 8 },
  subtitle: { fontSize: 16, color: colors.textMuted },
  card: { marginBottom: 32 },
  footer: { marginTop: 'auto' },
  footerText: { color: colors.textMuted, textAlign: 'center', marginBottom: 16 },
});
