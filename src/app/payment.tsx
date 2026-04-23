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

  // Since Razorpay requires native modules which cannot simply trigger here without config,
  // we will mock the payment flow for the frontend, but interact with actual backend /jobs API.
  
  const handleCheckout = async () => {
    setLoading(true);
    
    try {
      const userId = await SecureStore.getItemAsync('userId');
      const token = await SecureStore.getItemAsync('userToken');
      if (!userId) throw new Error("User not logged in");
      
      const locationId = params.locationId;
      if (!locationId) throw new Error("No location ID found. Please go back and select a location.");

      // 1. Upload the file to server now
      const fileUri = params.fileUri as string;
      const fileName = params.fileName as string;
      const fileMimeType = params.fileMimeType as string;
      if (!fileUri || !fileName) throw new Error("No file selected. Please go back and pick a document.");

      const formData = new FormData();
      formData.append('file', {
        uri: fileUri,
        name: fileName,
        type: fileMimeType || 'application/octet-stream',
      } as any);
      formData.append('userId', userId);

      const uploadUrl = `${api.defaults.baseURL}/files/upload`;
      const uploadResponse = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      });

      const uploadData = await uploadResponse.json();
      if (!uploadResponse.ok) {
        throw new Error(uploadData.MESSAGE || uploadData.message || 'File upload failed');
      }

      const fileId = uploadData.DATA?.fileId;
      if (!fileId) throw new Error("No file ID returned from server");

      // 2. Create the Print Job
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
      const totalCost = jobRes.data?.DATA?.totalCost || params.totalCost;
      if (!jobId) throw new Error(jobRes.data?.MESSAGE || "Failed to create print job");

      // 3. Create the Razorpay Order
      const orderRes = await api.post('/payments/create-order', { jobId });
      const order = orderRes.data?.DATA;
      
      if (order && order.orderId) {
        const amountInPaise = params.totalCost ? Math.round(parseFloat(params.totalCost as string) * 100).toString() : '100';

        const options = {
          description: 'Print Job Payment',
          image: 'https://i.imgur.com/3g7nmJC.jpg',
          currency: 'INR',
          key: process.env.EXPO_PUBLIC_RAZORPAY_KEY_ID || '',
          amount: amountInPaise,
          name: 'Campus Print',
          order_id: order.orderId,
          prefill: {
            email: 'student@campus.edu',
            contact: '9999999999',
            name: 'Student'
          },
          theme: {color: colors.primary}
        };

        RazorpayCheckout.open(options).then((data: any) => {
          Alert.alert('Success', `Payment successful! Payment ID: ${data.razorpay_payment_id}`);
          router.replace('/(tabs)/queue');
        }).catch((error: any) => {
          console.log('Razorpay Error:', error);
          Alert.alert('Payment Error', error.description || error.message || 'Payment cancelled or failed');
        });

      } else {
        throw new Error("Failed to generate Razorpay Order");
      }

    } catch (err: any) {
      console.log('Checkout Error:', err.response?.data || err.message);
      Alert.alert('Payment Error', err.response?.data?.MESSAGE || err.message || 'Could not reach backend');
    } finally {
      setLoading(false);
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
});
