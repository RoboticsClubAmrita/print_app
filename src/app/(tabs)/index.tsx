import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, RefreshControl } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as SecureStore from 'expo-secure-store';
import { GlassCard } from '../../components/GlassCard';
import { CustomButton } from '../../components/CustomButton';
import { colors } from '../../theme/colors';
import { api } from '../../api/client';

export default function HomeScreen() {
  const router = useRouter();
  const [userName, setUserName] = useState('');
  const [stats, setStats] = useState({ pending: 0, completed: 0 });
  const [refreshing, setRefreshing] = useState(false);

  const fetchDashboard = async () => {
    try {
      const userId = await SecureStore.getItemAsync('userId');
      if (userId) {
        // Fetch User Info
        const userRes = await api.get(`/users/${userId}`);
        if (userRes.data?.DATA?.name) {
          setUserName(userRes.data.DATA.name);
        }

        // Fetch User jobs to compute stats
        const jobsRes = await api.get(`/jobs/user/${userId}`);
        const jobsList = jobsRes.data?.DATA?.jobs || [];
        
        const pendingCount = jobsList.filter((j: any) => j.status === 'PENDING' || j.status === 'QUEUED').length;
        const completedCount = jobsList.filter((j: any) => j.status === 'COMPLETED').length;
        
        setStats({ pending: pendingCount, completed: completedCount });
      }
    } catch (err) {
      console.log('Error fetching dashboard', err);
    }
  };

  useEffect(() => {
    fetchDashboard();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchDashboard();
    setRefreshing(false);
  };

  const handleLogout = async () => {
    await SecureStore.deleteItemAsync('userToken');
    await SecureStore.deleteItemAsync('userId');
    router.replace('/auth/login');
  };

  return (
    <ScrollView 
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} />}
    >
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Hello, {userName || 'Student'}</Text>
          <Text style={styles.subtitle}>Welcome to CampusPrint</Text>
        </View>
        <Ionicons name="notifications-outline" size={28} color={colors.text} />
      </View>

      <GlassCard intensity={40} style={styles.balanceCard}>
        <Ionicons name="wallet-outline" size={24} color={colors.secondary} style={{ marginBottom: 8 }} />
        <Text style={styles.balanceLabel}>Total Jobs Completed</Text>
        <Text style={styles.balanceAmount}>{stats.completed}</Text>
      </GlassCard>

      <Text style={styles.sectionTitle}>Quick Actions</Text>
      <View style={styles.actionGrid}>
        <GlassCard style={styles.actionCard}>
           <Ionicons name="document-text-outline" size={32} color={colors.primary} />
           <Text style={styles.actionText}>New Print</Text>
           <CustomButton title="Start" variant="outline" onPress={() => router.push('/(tabs)/print')} style={{height: 40, marginTop: 12}} />
        </GlassCard>
        <GlassCard style={styles.actionCard}>
           <Ionicons name="time-outline" size={32} color={colors.secondary} />
           <Text style={styles.actionText}>{stats.pending} Pending</Text>
           <CustomButton title="View Queue" variant="outline" onPress={() => router.push('/(tabs)/queue')} style={{height: 40, marginTop: 12}} />
        </GlassCard>
      </View>

      <CustomButton title="Logout" variant="ghost" onPress={handleLogout} style={{ marginTop: 40 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 24, paddingTop: 60, paddingBottom: 100 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 32 },
  greeting: { fontSize: 28, fontWeight: '800', color: colors.text, marginBottom: 4 },
  subtitle: { fontSize: 16, color: colors.textMuted },
  balanceCard: { marginBottom: 32, paddingVertical: 24 },
  balanceLabel: { color: colors.textMuted, fontSize: 16, marginBottom: 8 },
  balanceAmount: { color: colors.text, fontSize: 40, fontWeight: '800' },
  sectionTitle: { fontSize: 20, fontWeight: '700', color: colors.text, marginBottom: 16 },
  actionGrid: { flexDirection: 'row', gap: 16 },
  actionCard: { flex: 1, alignItems: 'center', padding: 16 },
  actionText: { color: colors.text, fontSize: 16, fontWeight: '600', marginTop: 12 },
});
