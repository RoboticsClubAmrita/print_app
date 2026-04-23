import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, Switch, Alert, Platform, ActivityIndicator, Modal, TouchableOpacity, FlatList } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as SecureStore from 'expo-secure-store';
import { api } from '../../api/client';
import { GlassCard } from '../../components/GlassCard';
import { CustomButton } from '../../components/CustomButton';
import { InputField } from '../../components/InputField';
import { colors } from '../../theme/colors';

const FALLBACK_PRICING = {
  blackAndWhite: { single: 1, double: 1.5 }, // per page
  color: { single: 10, double: 8 }
};

export default function PrintConfigScreen() {
  const router = useRouter();
  const [file, setFile] = useState<any>(null);
  const [pageCount, setPageCount] = useState<string>('');
  
  const [isColor, setIsColor] = useState(false);
  const [isDoubleSided, setIsDoubleSided] = useState(false);
  const [copies, setCopies] = useState('1');
  
  const [outstandingBalance, setOutstandingBalance] = useState(0);
  const [totalCost, setTotalCost] = useState(0);

  const [serverPrices, setServerPrices] = useState<any[]>([]);
  const [locations, setLocations] = useState<any[]>([]);
  const [selectedLocation, setSelectedLocation] = useState<string>("");
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);

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

        try {
            const priceRes = await api.get('/pricing/all');
            const prices = priceRes.data?.DATA?.prices || [];
            setServerPrices(prices);
        } catch (err) {
            console.log("Failed to fetch pricing", err);
        }

        try {
            const locRes = await api.get('/hardware/locations');
            const locs = locRes.data?.DATA || [];
            setLocations(locs);
            if (locs.length > 0) setSelectedLocation(locs[0]._id);
        } catch (err) {
            console.log("Failed to fetch locations", err);
        }
    })();
  }, []);

  useEffect(() => {
    calculateCost();
  }, [pageCount, isColor, isDoubleSided, copies, serverPrices]);

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

  const calculateCost = () => {
    let pages = parseInt(pageCount) || 0;
    let copyNum = parseInt(copies) || 1;
    if (pages <= 0 || copyNum <= 0) {
      setTotalCost(0);
      return;
    }

    let rate = 0;
    
    if (serverPrices.length > 0) {
      const type = isColor ? 'colour' : 'bw';
      const side = isDoubleSided ? 'double' : 'single';
      // Default to A4 as it is currently the standard upload size
      const priceDoc = serverPrices.find(p => p.type === type && p.side === side && p.size === 'A4');
      if (priceDoc && priceDoc.price !== undefined) {
         rate = priceDoc.price;
      } else {
         rate = 2; // Fallback safe price if specific config is not found in DB
      }
    } else {
      // Fallback if API hasn't loaded yet
      const type = isColor ? FALLBACK_PRICING.color : FALLBACK_PRICING.blackAndWhite;
      rate = isDoubleSided ? type.double : type.single;
    }

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

  const pickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ALLOWED_MIME_TYPES,
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        const pickedFile = result.assets[0];
        const mimeType = pickedFile.mimeType || getMimeType(pickedFile.name);
        setFile({ name: pickedFile.name, uri: pickedFile.uri, mimeType });
        // For images, default to 1 page
        if (mimeType.startsWith('image/')) {
          setPageCount('1');
        }
      }
    } catch (err) {
      console.log('Error picking doc', err);
      Alert.alert('Error', 'Failed to pick document');
    }
  };

  const proceedToPayment = () => {
    if (!file) {
      Alert.alert('Validation', 'Please select a document first.');
      return;
    }
    const pages = parseInt(pageCount) || 0;
    if (pages <= 0) {
      Alert.alert('Validation', 'Please enter the number of pages.');
      return;
    }
    if (!selectedLocation) {
      Alert.alert('Validation', 'Please select an available printer location.');
      return;
    }
    
    router.push({
      pathname: '/payment',
      params: {
        fileUri: file.uri,
        fileName: file.name,
        fileMimeType: file.mimeType,
        pageCount: pages,
        copies: parseInt(copies) || 1,
        color: isColor ? 'true' : 'false',
        doubleSided: isDoubleSided ? 'true' : 'false',
        totalCost: totalCost.toString(),
        locationId: selectedLocation
      }
    });
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.headerTitle}>Print Document</Text>
      
      <GlassCard style={styles.uploadCard}>
        {file ? (
          <View style={styles.fileSelectedRow}>
            <Ionicons name="document" size={32} color={colors.primary} />
            <View style={{ flex: 1, marginLeft: 16 }}>
              <Text style={styles.fileName}>{file.name}</Text>
              <Text style={styles.filePages}>Ready to print</Text>
            </View>
            <CustomButton title="Change" variant="outline" onPress={pickDocument} style={{ height: 32, paddingHorizontal: 16, marginTop: 0 }} />
          </View>
        ) : (
          <View style={styles.uploadPlaceholder}>
            <Ionicons name="document-attach-outline" size={48} color={colors.textMuted} />
            <Text style={styles.uploadText}>Select a file to print (PDF, Word, JPG, PNG)</Text>
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
          label="Number of Pages"
          keyboardType="number-pad"
          value={pageCount}
          onChangeText={setPageCount}
          icon="document-text-outline"
        />
        <View style={styles.divider} />

        <InputField
          label="Number of Copies"
          keyboardType="number-pad"
          value={copies}
          onChangeText={setCopies}
          icon="copy-outline"
        />

        <View style={styles.divider} />
        
        <Text style={[styles.switchLabel, { marginBottom: 8 }]}>Select Printer Location</Text>
        {locations.length > 0 ? (
          <>
            <TouchableOpacity
              style={styles.dropdownButton}
              onPress={() => setShowLocationDropdown(true)}
              activeOpacity={0.7}
            >
              <Ionicons name="location-outline" size={20} color={colors.primary} style={{ marginRight: 10 }} />
              <Text style={styles.dropdownButtonText} numberOfLines={1}>
                {locations.find(l => l._id === selectedLocation)?.name || 'Select a location'}
              </Text>
              <Ionicons name="chevron-down" size={20} color={colors.textMuted} />
            </TouchableOpacity>

            <Modal
              visible={showLocationDropdown}
              transparent
              animationType="fade"
              onRequestClose={() => setShowLocationDropdown(false)}
            >
              <TouchableOpacity
                style={styles.modalOverlay}
                activeOpacity={1}
                onPress={() => setShowLocationDropdown(false)}
              >
                <View style={styles.modalContent}>
                  <View style={styles.modalHeader}>
                    <Text style={styles.modalTitle}>Select Printer Location</Text>
                    <TouchableOpacity onPress={() => setShowLocationDropdown(false)}>
                      <Ionicons name="close-circle" size={28} color={colors.textMuted} />
                    </TouchableOpacity>
                  </View>
                  <FlatList
                    data={locations}
                    keyExtractor={(item) => item._id}
                    renderItem={({ item }) => (
                      <TouchableOpacity
                        style={[
                          styles.dropdownItem,
                          selectedLocation === item._id && styles.dropdownItemSelected,
                        ]}
                        onPress={() => {
                          setSelectedLocation(item._id);
                          setShowLocationDropdown(false);
                        }}
                      >
                        <Ionicons
                          name={selectedLocation === item._id ? 'radio-button-on' : 'radio-button-off'}
                          size={22}
                          color={selectedLocation === item._id ? colors.primary : colors.textMuted}
                          style={{ marginRight: 12 }}
                        />
                        <View style={{ flex: 1 }}>
                          <Text style={[
                            styles.dropdownItemText,
                            selectedLocation === item._id && { color: colors.primary, fontWeight: '700' },
                          ]}>
                            {item.name}
                          </Text>
                          {item.address && (
                            <Text style={styles.dropdownItemAddress}>{item.address}</Text>
                          )}
                        </View>
                        {selectedLocation === item._id && (
                          <Ionicons name="checkmark-circle" size={22} color={colors.primary} />
                        )}
                      </TouchableOpacity>
                    )}
                    style={{ maxHeight: 350 }}
                  />
                </View>
              </TouchableOpacity>
            </Modal>
          </>
        ) : (
          <Text style={{ color: colors.error, fontSize: 14 }}>No printer locations available. Contact admin.</Text>
        )}
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

  dropdownButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceLight,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginVertical: 4,
  },
  dropdownButtonText: {
    flex: 1,
    color: colors.text,
    fontSize: 15,
    fontWeight: '500',
  },

  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  modalContent: {
    width: '100%',
    backgroundColor: colors.surface,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    padding: 20,
    maxHeight: '70%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: colors.text,
  },
  dropdownItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 12,
    borderRadius: 12,
    marginBottom: 6,
  },
  dropdownItemSelected: {
    backgroundColor: 'rgba(108, 93, 211, 0.12)',
    borderWidth: 1,
    borderColor: 'rgba(108, 93, 211, 0.3)',
  },
  dropdownItemText: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '500',
  },
  dropdownItemAddress: {
    color: colors.textDim,
    fontSize: 12,
    marginTop: 2,
  },
});
