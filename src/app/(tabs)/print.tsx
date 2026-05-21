import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';
import * as SecureStore from 'expo-secure-store';
import { useRouter } from 'expo-router';
import { GlassCard } from '../../components/GlassCard';
import { CustomButton } from '../../components/CustomButton';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function PrintScreen() {
  const router = useRouter();
  const [file, setFile] = useState<any>(null);
  
  // Upload state
  const [uploadingFile, setUploadingFile] = useState(false);
  const [uploadedFileId, setUploadedFileId] = useState<string | null>(null);
  const [uploadStatus, setUploadStatus] = useState('');

  // Settings
  const [color, setColor] = useState(false);
  const [doubleSided, setDoubleSided] = useState(false);
  const [copies, setCopies] = useState(1);
  const [pageCount, setPageCount] = useState(0);

  // Locations
  const [locations, setLocations] = useState<any[]>([]);
  const [selectedLocationId, setSelectedLocationId] = useState<string | null>(null);
  const [loadingLocations, setLoadingLocations] = useState(false);

  // Pricing
  const [pricePerPage, setPricePerPage] = useState<number>(2.00);
  const [loadingPrice, setLoadingPrice] = useState(false);

  // Fetch Locations
  const fetchLocations = async () => {
    setLoadingLocations(true);
    try {
      const res = await api.get('/hardware/locations');
      if (res.data?.DATA) {
        setLocations(res.data.DATA);
        if (res.data.DATA.length > 0) {
          setSelectedLocationId(res.data.DATA[0]._id);
        }
      }
    } catch (err: any) {
      console.log('Error fetching locations:', err.message);
    } finally {
      setLoadingLocations(false);
    }
  };

  // Fetch Pricing
  const fetchPrice = async () => {
    setLoadingPrice(true);
    try {
      const size = 'A4';
      const type = color ? 'colour' : 'bw';
      const side = doubleSided ? 'double' : 'single';
      
      const res = await api.get(`/pricing/lookup?size=${size}&type=${type}&side=${side}`);
      if (res.data?.DATA?.price) {
        setPricePerPage(res.data.DATA.price);
      } else if (res.data?.price) {
        setPricePerPage(res.data.price);
      }
    } catch (err) {
      setPricePerPage(color ? 10.00 : 2.00);
    } finally {
      setLoadingPrice(false);
    }
  };

  useEffect(() => {
    fetchLocations();
  }, []);

  useEffect(() => {
    fetchPrice();
  }, [color, doubleSided]);

  // Upload file to backend immediately on pick — backend detects page count accurately
  const uploadFileToServer = async (selectedFile: any) => {
    setUploadingFile(true);
    setUploadStatus('Uploading file...');
    setUploadedFileId(null);
    setPageCount(0);

    try {
      const userId = await SecureStore.getItemAsync('userId');
      const token = await SecureStore.getItemAsync('userToken');
      if (!userId || !token) {
        Alert.alert('Error', 'Please log in first.');
        setFile(null);
        return;
      }

      const formData = new FormData();
      formData.append('file', {
        uri: selectedFile.uri,
        name: selectedFile.name,
        type: selectedFile.mimeType || 'application/octet-stream',
      } as any);
      formData.append('userId', userId);

      const uploadUrl = `${api.defaults.baseURL}/files/upload`;
      const response = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': `Bearer ${token}`,
          // Do NOT set Content-Type — let fetch set the multipart boundary automatically
        },
        body: formData,
      });

      // Safe JSON parsing
      let data: any;
      try {
        const responseText = await response.text();
        data = JSON.parse(responseText);
      } catch {
        if (response.status === 413) {
          throw new Error('File is too large for the server. Ask your admin to increase the upload limit (nginx client_max_body_size).');
        }
        throw new Error(`Server returned an invalid response (HTTP ${response.status}). Try a smaller file.`);
      }

      if (!response.ok) {
        throw new Error(data.MESSAGE || data.message || `Upload failed (${response.status})`);
      }

      const fileId = data.DATA?.fileId;
      if (!fileId) throw new Error('Server did not return a file ID.');

      // Use backend-detected page count (parsed from PDF/DOCX by the server)
      const detectedPages = data.DATA?.metadata?.totalPages || 1;

      setUploadedFileId(fileId);
      setPageCount(detectedPages);
      setUploadStatus(`✅ Uploaded — ${detectedPages} page${detectedPages !== 1 ? 's' : ''} detected`);

    } catch (err: any) {
      console.log('Upload Error:', err);
      Alert.alert('Upload Failed', err.message || 'Could not upload file. Please try again.');
      setFile(null);
      setUploadedFileId(null);
      setPageCount(0);
      setUploadStatus('');
    } finally {
      setUploadingFile(false);
    }
  };

  // Pick Document — upload immediately after picking
  const pickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'image/*'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        const selectedFile = result.assets[0];
        setFile(selectedFile);
        // Upload immediately to get accurate page count from backend
        await uploadFileToServer(selectedFile);
      }
    } catch (err) {
      Alert.alert('Error', 'Failed to pick document.');
    }
  };

  // Remove file
  const removeFile = () => {
    setFile(null);
    setUploadedFileId(null);
    setPageCount(0);
    setUploadStatus('');
  };

  const handleIncrementCopies = () => setCopies(prev => prev + 1);
  const handleDecrementCopies = () => setCopies(prev => Math.max(1, prev - 1));

  const handleIncrementPages = () => setPageCount(prev => prev + 1);
  const handleDecrementPages = () => setPageCount(prev => Math.max(1, prev - 1));

  const totalCost = pageCount * pricePerPage * copies;

  const handleProceedToPayment = () => {
    if (!file) {
      Alert.alert('Error', 'Please select a document first.');
      return;
    }
    if (uploadingFile) {
      Alert.alert('Please Wait', 'File is still uploading...');
      return;
    }
    if (!uploadedFileId) {
      Alert.alert('Error', 'File upload failed. Please remove the file and try again.');
      return;
    }
    if (!selectedLocationId) {
      Alert.alert('Error', 'Please select a print location.');
      return;
    }
    if (pageCount <= 0) {
      Alert.alert('Error', 'Page count must be at least 1.');
      return;
    }

    // Navigate to payment screen — pass fileId (already uploaded), not fileUri
    router.push({
      pathname: '/payment',
      params: {
        fileId: uploadedFileId,
        fileName: file.name,
        fileMimeType: file.mimeType || 'application/pdf',
        locationId: selectedLocationId,
        color: String(color),
        doubleSided: String(doubleSided),
        copies: String(copies),
        pageCount: String(pageCount),
        totalCost: String(totalCost.toFixed(2)),
      }
    });
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.headerTitle}>New Print Job</Text>

      {/* Document Picker Card */}
      <TouchableOpacity onPress={uploadingFile ? undefined : pickDocument} activeOpacity={0.8} style={styles.pickerWrapper}>
        {file ? (
          <GlassCard style={styles.fileCard} intensity={35}>
            <View style={styles.fileHeader}>
              <Ionicons name="document-text" size={36} color={colors.primary} />
              <View style={styles.fileInfo}>
                <Text style={styles.fileName} numberOfLines={1}>{file.name}</Text>
                <Text style={styles.fileSize}>
                  {file.size ? `${(file.size / (1024 * 1024)).toFixed(2)} MB` : 'Document Selected'}
                </Text>
                {uploadingFile ? (
                  <View style={styles.uploadStatusRow}>
                    <ActivityIndicator size="small" color={colors.primary} />
                    <Text style={styles.uploadStatusText}>{uploadStatus}</Text>
                  </View>
                ) : uploadStatus ? (
                  <Text style={styles.uploadSuccessText}>{uploadStatus}</Text>
                ) : null}
              </View>
              {!uploadingFile && (
                <TouchableOpacity onPress={removeFile} style={styles.removeBtn}>
                  <Ionicons name="close-circle" size={24} color={colors.error} />
                </TouchableOpacity>
              )}
            </View>
          </GlassCard>
        ) : (
          <View style={styles.pickerOutline}>
            <Ionicons name="cloud-upload-outline" size={40} color={colors.primary} />
            <Text style={styles.pickerTitle}>Select Document</Text>
            <Text style={styles.pickerSub}>Tap to browse PDF or Image files (Max 50MB)</Text>
          </View>
        )}
      </TouchableOpacity>

      {file && uploadedFileId && !uploadingFile && (
        <View style={styles.settingsSection}>
          {/* Location Selector */}
          <Text style={styles.sectionLabel}>Select Print Location</Text>
          {loadingLocations ? (
            <ActivityIndicator color={colors.primary} style={{ marginVertical: 12 }} />
          ) : locations.length === 0 ? (
            <Text style={styles.noLocationsText}>No locations available</Text>
          ) : (
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.locationScroll}>
              {locations.map((loc) => {
                const isSelected = selectedLocationId === loc._id;
                return (
                  <TouchableOpacity
                    key={loc._id}
                    onPress={() => setSelectedLocationId(loc._id)}
                    style={[styles.locationChip, isSelected && styles.locationChipSelected]}
                  >
                    <Ionicons
                      name="location-outline"
                      size={16}
                      color={isSelected ? colors.background : colors.textMuted}
                    />
                    <Text style={[styles.locationChipText, isSelected && styles.locationChipTextSelected]}>
                      {loc.name}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          )}

          {/* Color Mode Selection */}
          <Text style={styles.sectionLabel}>Color Mode</Text>
          <View style={styles.rowGrid}>
            <TouchableOpacity
              onPress={() => setColor(false)}
              style={[styles.selectorBtn, !color && styles.selectorBtnActive]}
            >
              <Ionicons name="color-palette-outline" size={20} color={!color ? colors.background : colors.textMuted} />
              <Text style={[styles.selectorText, !color && styles.selectorTextActive]}>Black & White</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => setColor(true)}
              style={[styles.selectorBtn, color && styles.selectorBtnActive]}
            >
              <Ionicons name="color-palette" size={20} color={color ? colors.background : colors.textMuted} />
              <Text style={[styles.selectorText, color && styles.selectorTextActive]}>Color</Text>
            </TouchableOpacity>
          </View>

          {/* Side Configuration Selection */}
          <Text style={styles.sectionLabel}>Printing Sides</Text>
          <View style={styles.rowGrid}>
            <TouchableOpacity
              onPress={() => setDoubleSided(false)}
              style={[styles.selectorBtn, !doubleSided && styles.selectorBtnActive]}
            >
              <Ionicons name="document-outline" size={20} color={!doubleSided ? colors.background : colors.textMuted} />
              <Text style={[styles.selectorText, !doubleSided && styles.selectorTextActive]}>Single Sided</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => setDoubleSided(true)}
              style={[styles.selectorBtn, doubleSided && styles.selectorBtnActive]}
            >
              <Ionicons name="documents-outline" size={20} color={doubleSided ? colors.background : colors.textMuted} />
              <Text style={[styles.selectorText, doubleSided && styles.selectorTextActive]}>Double Sided</Text>
            </TouchableOpacity>
          </View>

          {/* Adjust Page Count and Copies */}
          <View style={styles.controlsRow}>
            {/* Total Pages Counter */}
            <View style={styles.controlBox}>
              <Text style={styles.controlLabel}>Pages (Detected)</Text>
              <View style={styles.counterRow}>
                <TouchableOpacity onPress={handleDecrementPages} style={styles.counterBtn}>
                  <Ionicons name="remove" size={20} color={colors.text} />
                </TouchableOpacity>
                <Text style={styles.counterValue}>{pageCount}</Text>
                <TouchableOpacity onPress={handleIncrementPages} style={styles.counterBtn}>
                  <Ionicons name="add" size={20} color={colors.text} />
                </TouchableOpacity>
              </View>
            </View>

            {/* Copies Counter */}
            <View style={styles.controlBox}>
              <Text style={styles.controlLabel}>Copies</Text>
              <View style={styles.counterRow}>
                <TouchableOpacity onPress={handleDecrementCopies} style={styles.counterBtn}>
                  <Ionicons name="remove" size={20} color={colors.text} />
                </TouchableOpacity>
                <Text style={styles.counterValue}>{copies}</Text>
                <TouchableOpacity onPress={handleIncrementCopies} style={styles.counterBtn}>
                  <Ionicons name="add" size={20} color={colors.text} />
                </TouchableOpacity>
              </View>
            </View>
          </View>

          {/* Price Calculation Card */}
          <GlassCard style={styles.costCard} intensity={25}>
            <View style={styles.costItem}>
              <Text style={styles.costLabel}>Price per page</Text>
              <Text style={styles.costValue}>
                {loadingPrice ? <ActivityIndicator size="small" color={colors.primary} /> : `₹${pricePerPage.toFixed(2)}`}
              </Text>
            </View>
            <View style={styles.costItem}>
              <Text style={styles.costLabel}>Pages × Copies</Text>
              <Text style={styles.costValue}>{pageCount} × {copies}</Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.costItem}>
              <Text style={styles.costTotalLabel}>Estimated Total</Text>
              <Text style={styles.costTotalValue}>₹{totalCost.toFixed(2)}</Text>
            </View>
          </GlassCard>

          {/* Action button */}
          <CustomButton
            title="Proceed to Payment"
            onPress={handleProceedToPayment}
            style={styles.actionBtn}
          />
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 24, paddingTop: 60, paddingBottom: 100 },
  headerTitle: { fontSize: 28, fontWeight: '800', color: colors.text, marginBottom: 24 },
  
  pickerWrapper: { marginBottom: 24 },
  pickerOutline: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: colors.border,
    borderRadius: 20,
    padding: 32,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(26, 31, 44, 0.4)',
  },
  pickerTitle: { fontSize: 18, fontWeight: '700', color: colors.text, marginTop: 12 },
  pickerSub: { fontSize: 12, color: colors.textMuted, marginTop: 6, textAlign: 'center' },
  
  fileCard: { padding: 20 },
  fileHeader: { flexDirection: 'row', alignItems: 'center' },
  fileInfo: { flex: 1, marginLeft: 16 },
  fileName: { fontSize: 16, fontWeight: '600', color: colors.text },
  fileSize: { fontSize: 13, color: colors.textMuted, marginTop: 4 },
  removeBtn: { padding: 4 },

  uploadStatusRow: { flexDirection: 'row', alignItems: 'center', marginTop: 6, gap: 8 },
  uploadStatusText: { fontSize: 12, color: colors.primary },
  uploadSuccessText: { fontSize: 12, color: '#4CAF50', marginTop: 6, fontWeight: '600' },

  settingsSection: { marginTop: 8 },
  sectionLabel: { fontSize: 13, fontWeight: '700', color: colors.textMuted, marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.5 },
  
  locationScroll: { paddingBottom: 16, gap: 10 },
  locationChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 12,
  },
  locationChipSelected: {
    backgroundColor: colors.secondary,
    borderColor: colors.secondary,
  },
  locationChipText: { color: colors.textMuted, fontSize: 14, fontWeight: '600' },
  locationChipTextSelected: { color: colors.background, fontWeight: '700' },
  noLocationsText: { color: colors.textDim, fontSize: 14, marginBottom: 16 },

  rowGrid: { flexDirection: 'row', gap: 12, marginBottom: 24 },
  selectorBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    height: 52,
    borderRadius: 14,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  selectorBtnActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  selectorText: { color: colors.textMuted, fontSize: 14, fontWeight: '600' },
  selectorTextActive: { color: colors.background, fontWeight: '700' },

  controlsRow: { flexDirection: 'row', gap: 16, marginBottom: 24 },
  controlBox: { flex: 1 },
  controlLabel: { fontSize: 14, fontWeight: '600', color: colors.textMuted, marginBottom: 8 },
  counterRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.surface,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: 8,
    height: 50,
  },
  counterBtn: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: colors.surfaceLight,
    alignItems: 'center',
    justifyContent: 'center',
  },
  counterValue: { fontSize: 16, fontWeight: '700', color: colors.text },

  costCard: { padding: 20, marginBottom: 24 },
  costItem: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  costLabel: { fontSize: 14, color: colors.textMuted },
  costValue: { fontSize: 16, fontWeight: '600', color: colors.text },
  divider: { height: 1, backgroundColor: colors.glassBorder, marginVertical: 10 },
  costTotalLabel: { fontSize: 16, fontWeight: '700', color: colors.text },
  costTotalValue: { fontSize: 22, fontWeight: '800', color: colors.secondary },
  
  actionBtn: { marginTop: 8 },
});
