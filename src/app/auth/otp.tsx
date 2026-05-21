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
    email: string;
  }>();
  const router = useRouter();
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);

  const handleVerify = async () => {
    if (!otp || otp.length < 6) {
      Alert.alert('Error', 'Please enter the 6-digit verification code.');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post('/auth/verify-email', {
        email: params.email,
        otp: otp
      });
      if (res.status === 200 || res.status === 201) {
        Alert.alert('Success', 'Email verified successfully! You can now log in.');
        router.replace('/auth/login');
      }
    } catch (err: any) {
      const msg = err.response?.data?.MESSAGE || err.response?.data?.message || err.message || 'Verification failed';
      Alert.alert('Error', msg);
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    setResending(true);
    try {
      const res = await api.post('/auth/resend-verification', {
        email: params.email
      });
      if (res.status === 200 || res.status === 201) {
        Alert.alert('Success', 'A new verification code has been sent to your email.');
      }
    } catch (err: any) {
      const msg = err.response?.data?.MESSAGE || err.response?.data?.message || err.message || 'Failed to resend code';
      Alert.alert('Error', msg);
    } finally {
      setResending(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Verification</Text>
        <Text style={styles.subtitle}>Enter the 6-digit OTP sent to {params.email}</Text>
      </View>

      <GlassCard style={styles.card}>
        <InputField
          label="Verification Code"
          placeholder="1 2 3 4 5 6"
          keyboardType="number-pad"
          maxLength={6}
          style={{ textAlign: 'center', fontSize: 24, letterSpacing: 8 }}
          value={otp}
          onChangeText={setOtp}
        />
        <CustomButton title="Verify Account" onPress={handleVerify} loading={loading} />
        <CustomButton 
          title="Resend Verification Code" 
          variant="ghost" 
          onPress={handleResend} 
          loading={resending} 
        />
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
