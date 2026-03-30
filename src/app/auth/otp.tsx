import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert, ScrollView } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { GlassCard } from '../../components/GlassCard';
import { InputField } from '../../components/InputField';
import { CustomButton } from '../../components/CustomButton';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function OtpScreen() {
  const params = useLocalSearchParams<{
    name: string;
    email: string;
    password: string;
    collegeId: string;
  }>();
  const router = useRouter();
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);

  const handleVerify = async () => {
    if (otp !== '1234') {
      Alert.alert('Mock OTP', 'Since email/SMS integration is pending, please use 1234 for demo verification');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post('/users/add', {
        name: params.name,
        email: params.email,
        password: params.password,
        collegeId: params.collegeId,
        phone: '1234567890', // placeholder
        role: 'student'
      });
      if (res.status === 200 || res.status === 201) {
        Alert.alert('Success', 'Account created! Please sign in.');
        router.replace('/auth/login');
      }
    } catch (err: any) {
      const msg = err.response?.data?.MESSAGE || err.response?.data?.message || err.message || 'Registration failed';
       // the backend returns a 400 for duplicate email: "User already exists"
      if (msg === 'User already exists') {
         Alert.alert('Error', 'User already exists. Redirecting to login.');
         router.replace('/auth/login');
      } else {
         Alert.alert('Error', msg);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Verification</Text>
        <Text style={styles.subtitle}>Enter the 4-digit OTP sent to {params.email}</Text>
      </View>

      <GlassCard style={styles.card}>
        <InputField
          label="Verification Code"
          placeholder="1 2 3 4"
          keyboardType="number-pad"
          maxLength={4}
          style={{ textAlign: 'center', fontSize: 24, letterSpacing: 8 }}
          value={otp}
          onChangeText={setOtp}
        />
        <CustomButton title="Verify Account" onPress={handleVerify} loading={loading} />
      </GlassCard>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flexGrow: 1, backgroundColor: colors.background, padding: 24, paddingTop: 60 },
  header: { marginBottom: 32 },
  title: { fontSize: 32, fontWeight: '800', color: colors.text, marginBottom: 8 },
  subtitle: { fontSize: 16, color: colors.textMuted },
  card: { marginBottom: 32 },
});
