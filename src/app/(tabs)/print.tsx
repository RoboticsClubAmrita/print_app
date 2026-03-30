import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, Switch, Alert, Platform, ActivityIndicator } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as SecureStore from 'expo-secure-store';
import { api } from '../../api/client';
import { GlassCard } from '../../components/GlassCard';
import { CustomButton } from '../../components/CustomButton';
import { InputField } from '../../components/InputField';
import { colors } from '../../theme/colors';

const PRICING = {
  blackAndWhite: { single: 2, double: 1.5 }, // per page
  color: { single: 10, double: 8 }
};

export default function PrintConfigScreen() {
  const router = useRouter();
  const [file, setFile] = useState<any>(null);
  const [pageCount, setPageCount] = useState<number>(0);
  
  const [isColor, setIsColor] = useState(false);
  const [isDoubleSided, setIsDoubleSided] = useState(false);
  const [copies, setCopies] = useState('1');
  
  const [outstandingBalance, setOutstandingBalance] = useState(0);
  const [totalCost, setTotalCost] = useState(0);

  useEffect(() => {
    (async () => {
        try {
            const userId = await SecureStore.getItemAsync('userId');
            if (!userId) return;
            const res = await api.get(`/users/${userId}`);
            const balance = res.data?.DATA?.balance || 0;
            setOutstandingBalance(balance);
        } catch (err) {
            console.log("Failed to fetch user balance", err);
        }
    })();
  }, []);

  useEffect(() => {
    calculateCost();
  }, [pageCount, isColor, isDoubleSided, copies]);

  const calculateCost = () => {
    let pages = pageCount;
    let copyNum = parseInt(copies) || 1;
    if (pages <= 0 || copyNum <= 0) {
      setTotalCost(0);
      return;
    }

    const type = isColor ? PRICING.color : PRICING.blackAndWhite;
    const rate = isDoubleSided ? type.double : type.single;
    
    // Total physical papers used logic if double sided, but we'll charge per logical page
    let finalCost = pages * rate * copyNum;
    setTotalCost(finalCost + outstandingBalance);
  };

  const ALLOWED_MIME_TYPES = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
  ];

  const getMimeType = (fileName: string): string => {
    const ext = fileName.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  };

  const pickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ALLOWED_MIME_TYPES,
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        const pickedFile = result.assets[0];
        
        await uploadAndParseFile(pickedFile);
      }
    } catch (err) {
      console.log('Error picking doc', err);
      Alert.alert('Error', 'Failed to pick document');
    }
  };

  const [isUploading, setIsUploading] = useState(false);

  const uploadAndParseFile = async (pickedFile: any) => {
    setIsUploading(true);
    setPageCount(0);
    try {
      const userId = await SecureStore.getItemAsync('userId');
      const token = await SecureStore.getItemAsync('userToken');
      const fileMimeType = pickedFile.mimeType || getMimeType(pickedFile.name);

      const formData = new FormData();
      formData.append('file', {
        uri: pickedFile.uri,
        name: pickedFile.name,
        type: fileMimeType,
      } as any);
      formData.append('userId', userId || 'unknown');

      const uploadUrl = `${api.defaults.baseURL}/files/upload`;
      const response = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      });
      
      const responseData = await response.json();
      
      if (!response.ok) {
        throw new Error(responseData.MESSAGE || responseData.message || 'Server returned an error');
      }
      
      const fileId = responseData.DATA?.fileId;
      const pages = responseData.DATA?.metadata?.totalPages || 1;

      if (!fileId) throw new Error("No file ID returned from server");

      setFile({ name: pickedFile.name, uri: pickedFile.uri, fileId });
      setPageCount(pages);
      
    } catch (e: any) {
      console.log('Upload error', e.message);
      Alert.alert('Upload Error', e.message || 'Failed to upload file');
    } finally {
      setIsUploading(false);
    }
  };

  const proceedToPayment = () => {
    if (!file) {
      Alert.alert('Validation', 'Please select a document first.');
      return;
    }
    
    router.push({
      pathname: '/payment',
      params: {
        fileId: file.fileId,
        fileName: file.name,
        pageCount,
        copies: parseInt(copies) || 1,
        color: isColor ? 'true' : 'false',
        doubleSided: isDoubleSided ? 'true' : 'false',
        totalCost: totalCost.toString()
      }
    });
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.headerTitle}>Print Document</Text>
      
      <GlassCard style={styles.uploadCard}>
        {isUploading ? (
          <View style={styles.uploadPlaceholder}>
            <ActivityIndicator size="large" color={colors.primary} />
            <Text style={styles.uploadText}>Uploading and parsing file...</Text>
          </View>
        ) : file ? (
          <View style={styles.fileSelectedRow}>
            <Ionicons name="document" size={32} color={colors.primary} />
            <View style={{ flex: 1, marginLeft: 16 }}>
              <Text style={styles.fileName}>{file.name}</Text>
              <Text style={styles.filePages}>{pageCount} Pages detected</Text>
            </View>
            <CustomButton title="Change" variant="outline" onPress={pickDocument} style={{ height: 32, paddingHorizontal: 16, marginTop: 0 }} />
          </View>
        ) : (
          <View style={styles.uploadPlaceholder}>
            <Ionicons name="cloud-upload-outline" size={48} color={colors.textMuted} />
            <Text style={styles.uploadText}>Upload a file to print (PDF, Word, JPG, PNG)</Text>
            <CustomButton title="Browse Files" onPress={pickDocument} style={{ marginTop: 16, width: '100%' }} />
          </View>
        )}
      </GlassCard>

      <Text style={styles.sectionTitle}>Print Configuration</Text>
      <GlassCard style={styles.configCard}>
        <View style={styles.switchRow}>
           <Text style={styles.switchLabel}>Print in Color</Text>
           <Switch value={isColor} onValueChange={setIsColor} trackColor={{ false: colors.border, true: colors.primary }} />
        </View>
        <View style={styles.divider} />
        
        <View style={styles.switchRow}>
           <Text style={styles.switchLabel}>Double-sided</Text>
           <Switch value={isDoubleSided} onValueChange={setIsDoubleSided} trackColor={{ false: colors.border, true: colors.primary }} />
        </View>
        <View style={styles.divider} />
        
        <InputField
          label="Number of Copies"
          keyboardType="number-pad"
          value={copies}
          onChangeText={setCopies}
          icon="copy-outline"
        />
      </GlassCard>

      <GlassCard style={styles.costCard}>
        {outstandingBalance > 0 && (
            <View style={{ width: '100%', marginBottom: 12 }}>
                <View style={styles.costRow}>
                    <Text style={styles.costDetailLabel}>Document Print Cost</Text>
                    <Text style={styles.costDetailValue}>₹ {(totalCost - outstandingBalance).toFixed(2)}</Text>
                </View>
                <View style={styles.costRow}>
                    <Text style={styles.costDetailLabel}>Outstanding Storage Fees</Text>
                    <Text style={styles.costDetailValue}>₹ {outstandingBalance.toFixed(2)}</Text>
                </View>
                <View style={[styles.divider, { marginTop: 8, marginBottom: 8 }]} />
            </View>
        )}
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', width: '100%', alignItems: 'center' }}>
            <Text style={styles.costLabel}>Total Payment</Text>
            <Text style={styles.costValue}>₹ {totalCost.toFixed(2)}</Text>
        </View>
      </GlassCard>

      <CustomButton title="Proceed to Payment" onPress={proceedToPayment} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 24, paddingTop: 60, paddingBottom: 100 },
  headerTitle: { fontSize: 28, fontWeight: '800', color: colors.text, marginBottom: 24 },
  sectionTitle: { fontSize: 20, fontWeight: '700', color: colors.text, marginBottom: 16, marginTop: 24 },
  
  uploadCard: { padding: 24, alignItems: 'center', justifyContent: 'center', minHeight: 180 },
  uploadPlaceholder: { alignItems: 'center', width: '100%' },
  uploadText: { color: colors.textMuted, marginTop: 16, textAlign: 'center' },
  
  fileSelectedRow: { flexDirection: 'row', alignItems: 'center', width: '100%' },
  fileName: { color: colors.text, fontWeight: '600', fontSize: 16 },
  filePages: { color: colors.secondary, fontSize: 14, marginTop: 4 },
  
  configCard: { padding: 24 },
  switchRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8 },
  switchLabel: { color: colors.text, fontSize: 16, fontWeight: '600' },
  divider: { height: 1, backgroundColor: colors.border, marginVertical: 12 },
  
  costCard: { padding: 24, marginVertical: 24, alignItems: 'center' },
  costRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  costDetailLabel: { color: colors.textDim, fontSize: 14 },
  costDetailValue: { color: colors.text, fontSize: 14, fontWeight: '600' },
  costLabel: { color: colors.textMuted, fontSize: 18 },
  costValue: { color: colors.text, fontSize: 28, fontWeight: '800' },
});
