import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Alert, ActivityIndicator } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as SecureStore from 'expo-secure-store';
import { GlassCard } from '../components/GlassCard';
import { CustomButton } from '../components/CustomButton';
import { colors } from '../theme/colors';
import { api } from '../api/client';
import RazorpayCheckout from 'react-native-razorpay';

export default function PaymentScreen() {
  const params = useLocalSearchParams();
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [statusText, setStatusText] = useState('');

  const handleCheckout = async () => {
    setLoading(true);
    setStatusText('Preparing...');
    
    try {
      const userId = await SecureStore.getItemAsync('userId');
      const token = await SecureStore.getItemAsync('userToken');
      if (!userId) throw new Error("User not logged in");
      
      const locationId = params.locationId;
      if (!locationId) throw new Error("No location ID found. Please go back and select a location.");

      // File was already uploaded on the Print screen — use the fileId directly
      const fileId = params.fileId as string;
      if (!fileId) throw new Error("File was not uploaded. Please go back and select a document again.");

      setStatusText('Creating print job...');

      // 1. Create the Print Job
      const jobPayload = {
        userId,
        fileId,
        locationId: locationId,
        colorMode: params.color === 'true' ? 'COLOR' : 'BW',
        printSide: params.doubleSided === 'true' ? 'DOUBLE' : 'SINGLE',
        copies: parseInt(params.copies as string) || 1,
        pageType: 'A4',
        totalPagesToPrint: parseInt(params.pageCount as string) || 1,
        currency: 'INR'
      };

      const jobRes = await api.post('/jobs/create', jobPayload);
      const jobId = jobRes.data?.DATA?.jobId;
      if (!jobId) throw new Error(jobRes.data?.MESSAGE || "Failed to create print job");

      setStatusText('Creating payment order...');

      // 2. Create the Razorpay Order
      const orderRes = await api.post('/payments/create-order', { jobId });
      const order = orderRes.data?.DATA;
      
      if (order && order.orderId) {
        // Use the amount from the backend order (accurate cost based on detected pages)
        const amountInPaise = order.amountInPaise
          ? String(order.amountInPaise)
          : Math.round((order.amount || parseFloat(params.totalCost as string) || 1) * 100).toString();

        const options = {
          description: 'Print Job Payment',
          image: 'https://i.imgur.com/3g7nmJC.jpg',
          currency: order.currency || 'INR',
          key: order.keyId || process.env.EXPO_PUBLIC_RAZORPAY_KEY_ID || '',
          amount: amountInPaise,
          name: 'Campus Print',
          order_id: order.orderId,
          prefill: {
            email: 'student@campus.edu',
            contact: '9999999999',
            name: 'Student'
          },
          theme: { color: colors.primary }
        };

        setStatusText('Opening payment gateway...');

        try {
          const data: any = await RazorpayCheckout.open(options);

          setStatusText('Verifying payment...');

          // 3. Verify payment with backend
          try {
            await api.post('/payments/verify', {
              razorpay_order_id: data.razorpay_order_id || order.orderId,
              razorpay_payment_id: data.razorpay_payment_id,
              razorpay_signature: data.razorpay_signature,
            });
          } catch (verifyErr: any) {
            console.log('Payment verification call failed (webhook will handle):', verifyErr.message);
          }

          Alert.alert('Success', `Payment successful! Payment ID: ${data.razorpay_payment_id}`);
          router.replace('/(tabs)/queue');
        } catch (rzpError: any) {
          console.log('Razorpay Error:', rzpError);
          Alert.alert('Payment Error', rzpError.description || rzpError.message || 'Payment cancelled or failed');
        }

      } else {
        throw new Error(orderRes.data?.MESSAGE || "Failed to generate Razorpay Order");
      }

    } catch (err: any) {
      console.log('Checkout Error:', err.response?.data || err.message);
      Alert.alert('Payment Error', err.response?.data?.MESSAGE || err.message || 'Could not reach backend');
    } finally {
      setLoading(false);
      setStatusText('');
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Ionicons name="cart-outline" size={48} color={colors.primary} style={styles.icon} />
      <Text style={styles.headerTitle}>Review & Pay</Text>
      
      <GlassCard style={styles.summaryCard}>
        <View style={styles.summaryRow}>
           <Text style={styles.summaryLabel}>File</Text>
           <Text style={styles.summaryValue}>{params.fileName}</Text>
        </View>
        <View style={styles.summaryRow}>
           <Text style={styles.summaryLabel}>Pages</Text>
           <Text style={styles.summaryValue}>{params.pageCount}</Text>
        </View>
        <View style={styles.summaryRow}>
           <Text style={styles.summaryLabel}>Options</Text>
           <Text style={styles.summaryValue}>
             {params.color === 'true' ? 'Color' : 'B&W'} • {params.doubleSided === 'true' ? 'Double' : 'Single'} • {params.copies}x
           </Text>
        </View>
        
        <View style={[styles.summaryRow, styles.totalRow]}>
           <Text style={styles.totalLabel}>Total to Pay</Text>
           <Text style={styles.totalValue}>₹{params.totalCost}</Text>
        </View>
      </GlassCard>

      <Text style={styles.paymentMethodTitle}>Select Payment Method</Text>
      
      <GlassCard style={styles.methodCard}>
        <Ionicons name="card-outline" size={24} color={colors.text} />
        <Text style={styles.methodText}>Razorpay (Cards / UPI / Netbanking)</Text>
        <Ionicons name="checkmark-circle" size={24} color={colors.primary} />
      </GlassCard>

      {statusText ? (
        <View style={styles.statusRow}>
          <ActivityIndicator size="small" color={colors.primary} />
          <Text style={styles.statusText}>{statusText}</Text>
        </View>
      ) : null}

      <CustomButton 
        title={`Pay ₹${params.totalCost}`} 
        onPress={handleCheckout} 
        loading={loading}
        style={{ marginTop: 40 }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 24, paddingTop: 60, paddingBottom: 100 },
  icon: { alignSelf: 'center', marginBottom: 16 },
  headerTitle: { fontSize: 28, fontWeight: '800', color: colors.text, textAlign: 'center', marginBottom: 32 },
  
  summaryCard: { padding: 24, marginBottom: 32 },
  summaryRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 16 },
  summaryLabel: { color: colors.textMuted, fontSize: 16 },
  summaryValue: { color: colors.text, fontSize: 16, fontWeight: '600', maxWidth: 200, textAlign: 'right' },
  
  totalRow: { marginTop: 16, paddingTop: 16, borderTopWidth: 1, borderTopColor: colors.border },
  totalLabel: { color: colors.text, fontSize: 18, fontWeight: '700' },
  totalValue: { color: colors.secondary, fontSize: 24, fontWeight: '800' },
  
  paymentMethodTitle: { fontSize: 18, color: colors.text, fontWeight: '600', marginBottom: 16 },
  methodCard: { flexDirection: 'row', alignItems: 'center', padding: 16, borderColor: colors.primary, borderWidth: 1 },
  methodText: { flex: 1, marginLeft: 16, color: colors.text, fontSize: 16 },

  statusRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20, gap: 10 },
  statusText: { color: colors.textMuted, fontSize: 14 },
});
