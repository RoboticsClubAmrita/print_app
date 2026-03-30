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
    // Send OTP first or just register directly if OTP is not implemented on backend
    // Since backend does not have OTP currently, we will assume we verify via an external/mock service 
    // or just register. 
    // We will navigate to OTP screen for demo.
    setTimeout(() => {
      setLoading(false);
      Alert.alert('Developer Mode', 'OTP sent simulated. Please use 1234 on the next screen.');
      router.push({
        pathname: '/auth/otp',
        params: { name, email: lowerEmail, password, collegeId }
      });
    }, 1000);
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
