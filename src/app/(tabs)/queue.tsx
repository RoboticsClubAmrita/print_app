import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, FlatList, RefreshControl, TouchableOpacity, Alert, Modal, TextInput } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as SecureStore from 'expo-secure-store';
import { GlassCard } from '../../components/GlassCard';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function QueueScreen() {
  const [jobs, setJobs] = useState<any[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  
  const [otpModalVisible, setOtpModalVisible] = useState(false);
  const [currentCollectJobId, setCurrentCollectJobId] = useState<string | null>(null);
  const [otp, setOtp] = useState('');

  const fetchJobs = async () => {
    try {
      const userId = await SecureStore.getItemAsync('userId');
      if (!userId) return;

      const res = await api.get(`/jobs/user/${userId}`);
      if (res.data?.DATA?.jobs) {
        setJobs(res.data.DATA.jobs);
      }
    } catch (err) {
      console.log('Error fetching jobs', err);
    }
  };

  useEffect(() => {
    fetchJobs();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchJobs();
    setRefreshing(false);
  };

  const handleDeleteJob = (jobId: string) => {
    Alert.alert(
      "Delete Job",
      "Are you sure you want to delete this print job? The uploaded file will also be permanently removed.",
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive",
          onPress: async () => {
            try {
              await api.delete('/jobs/delete', { data: { jobId: jobId } });
              Alert.alert("Success", "Print job and file deleted.");
              fetchJobs();
            } catch (err: any) {
              Alert.alert("Error", err.response?.data?.MESSAGE || "Could not delete job.");
            }
          }
        }
      ]
    );
  };

  const requestCollect = async (jobId: string) => {
    try {
        await api.post('/jobs/collect/request', { jobId: jobId });
        setCurrentCollectJobId(jobId);
        setOtpModalVisible(true);
    } catch(err: any) {
        Alert.alert("Error", err.response?.data?.MESSAGE || "Failed to request collect");
    }
  };

  const verifyCollect = async () => {
    if (!currentCollectJobId || !otp) return;
    try {
        const response = await api.post('/jobs/collect/verify', { jobId: currentCollectJobId, otp });
        const stackName = response.data?.DATA?.stackName || 'the assigned stack';
        Alert.alert("Success", `Job collected! Please take your materials from: ${stackName}`);
        setOtpModalVisible(false);
        setOtp('');
        fetchJobs();
    } catch(err: any) {
        Alert.alert("Error", err.response?.data?.MESSAGE || "Failed to verify OTP");
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'COLLECTED': return colors.success;
      case 'PRINTED': return colors.primary;
      case 'PRINTED_PENDING_STACK': return colors.warning;
      case 'PROCESSING': 
      case 'PRINTING': return colors.secondary;
      case 'PENDING':
      case 'QUEUED':
      default: return colors.textDim;
    }
  };

  const renderJobItem = ({ item }: { item: any }) => (
    <GlassCard style={styles.jobCard} intensity={25}>
      <View style={styles.jobHeader}>
        <Ionicons name="document-text" size={24} color={colors.text} />
        <View style={styles.jobInfo}>
          <Text style={styles.jobTitle} numberOfLines={1}>{item.originalName || 'Document.pdf'}</Text>
          <Text style={styles.jobDate}>{new Date(item.createdAt).toLocaleDateString()} {new Date(item.createdAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</Text>
        </View>
        <View style={styles.statusActionRow}>
          <Text style={[styles.statusBadge, { color: getStatusColor(item.status), borderColor: getStatusColor(item.status) }]}>
            {item.status}
          </Text>
          {item.status !== 'COLLECTED' && item.status !== 'PRINTING' && item.status !== 'PRINTED' && item.status !== 'PRINTED_PENDING_STACK' && (
            <TouchableOpacity onPress={() => handleDeleteJob(item._id)} style={styles.deleteButton}>
              <Ionicons name="trash-outline" size={20} color={colors.error || '#FF3B30'} />
            </TouchableOpacity>
          )}
        </View>
      </View>
      <View style={styles.jobDetails}>
        <Text style={styles.detailText}>Pages: {item.totalPagesToPrint || 0}</Text>
        <Text style={styles.detailText}>Copies: {item.copies || 1}</Text>
        <Text style={styles.detailText}>Cost: ₹{item.totalCost || 0}</Text>
      </View>
      {item.status === 'PRINTED' && (
        <TouchableOpacity style={styles.collectButton} onPress={() => requestCollect(item._id)}>
            <Text style={styles.collectButtonText}>Collect Materials</Text>
        </TouchableOpacity>
      )}
    </GlassCard>
  );

  return (
    <View style={styles.container}>
      <Text style={styles.headerTitle}>Print Queue</Text>
      
      <FlatList
        data={jobs}
        keyExtractor={(item, index) => item._id || index.toString()}
        renderItem={renderJobItem}
        contentContainerStyle={styles.listContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} />}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="documents-outline" size={64} color={colors.border} />
            <Text style={styles.emptyText}>No print jobs in queue</Text>
          </View>
        }
      />

      <Modal animationType="slide" transparent={true} visible={otpModalVisible} onRequestClose={() => setOtpModalVisible(false)}>
        <View style={styles.modalOverlay}>
            <View style={styles.modalContent}>
                <Text style={styles.modalTitle}>Enter OTP</Text>
                <Text style={styles.modalDesc}>Please check your email for the 4-digit collection OTP.</Text>
                <TextInput style={styles.otpInput} keyboardType="number-pad" maxLength={4} value={otp} onChangeText={setOtp} placeholder="0000" placeholderTextColor={colors.textMuted}/>
                <View style={styles.modalActions}>
                    <TouchableOpacity style={styles.modalBtnCancel} onPress={() => setOtpModalVisible(false)}><Text style={styles.modalBtnTextCancel}>Cancel</Text></TouchableOpacity>
                    <TouchableOpacity style={styles.modalBtnVerify} onPress={verifyCollect}><Text style={styles.modalBtnTextVerify}>Verify</Text></TouchableOpacity>
                </View>
            </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, paddingTop: 60 },
  headerTitle: { fontSize: 28, fontWeight: '800', color: colors.text, marginBottom: 24, paddingHorizontal: 24 },
  listContent: { paddingHorizontal: 24, paddingBottom: 100 },
  
  jobCard: { marginBottom: 16, padding: 16 },
  jobHeader: { flexDirection: 'row', alignItems: 'center' },
  jobInfo: { flex: 1, marginLeft: 16, marginRight: 8 },
  jobTitle: { color: colors.text, fontSize: 16, fontWeight: '600' },
  jobDate: { color: colors.textMuted, fontSize: 12, marginTop: 4 },
  
  statusActionRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  statusBadge: { borderWidth: 1, paddingHorizontal: 8, paddingVertical: 4, borderRadius: 12, fontSize: 10, fontWeight: '700' },
  deleteButton: { padding: 4 },
  
  jobDetails: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 16, paddingTop: 16, borderTopWidth: 1, borderTopColor: colors.glassBorder },
  detailText: { color: colors.textDim, fontSize: 13 },
  
  collectButton: { marginTop: 16, backgroundColor: colors.primary, paddingVertical: 12, borderRadius: 12, alignItems: 'center' },
  collectButtonText: { color: colors.background, fontWeight: '700', fontSize: 16 },

  emptyContainer: { alignItems: 'center', marginTop: 64 },
  emptyText: { color: colors.textMuted, marginTop: 16, fontSize: 16 },

  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', alignItems: 'center' },
  modalContent: { width: '85%', backgroundColor: colors.surface, borderRadius: 24, padding: 24, alignItems: 'center', borderWidth: 1, borderColor: colors.border },
  modalTitle: { fontSize: 20, fontWeight: '700', color: colors.text, marginBottom: 8 },
  modalDesc: { fontSize: 14, color: colors.textMuted, textAlign: 'center', marginBottom: 24 },
  otpInput: { width: '100%', backgroundColor: colors.background, color: colors.text, fontSize: 24, textAlign: 'center', padding: 16, borderRadius: 16, letterSpacing: 10, marginBottom: 24, borderWidth: 1, borderColor: colors.border },
  modalActions: { flexDirection: 'row', gap: 12, width: '100%' },
  modalBtnCancel: { flex: 1, padding: 16, borderRadius: 12, alignItems: 'center', backgroundColor: colors.surfaceLight },
  modalBtnVerify: { flex: 1, padding: 16, borderRadius: 12, alignItems: 'center', backgroundColor: colors.primary },
  modalBtnTextCancel: { color: colors.text, fontWeight: '600' },
  modalBtnTextVerify: { color: colors.background, fontWeight: '600' },
});
