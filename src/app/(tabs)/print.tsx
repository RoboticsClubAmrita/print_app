import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { GlassCard } from '../../components/GlassCard';
import { colors } from '../../theme/colors';

export default function PrintScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.headerTitle}>Print</Text>

      <GlassCard style={styles.infoCard}>
        <Ionicons name="information-circle-outline" size={48} color={colors.primary} />
        <Text style={styles.infoTitle}>Print Jobs Managed by Admin</Text>
        <Text style={styles.infoText}>
          Print jobs are created and managed through the administrator dashboard.
          Check the Queue tab to view the status of your pending jobs.
        </Text>
      </GlassCard>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 24, paddingTop: 60, paddingBottom: 100 },
  headerTitle: { fontSize: 28, fontWeight: '800', color: colors.text, marginBottom: 24 },
  infoCard: { padding: 32, alignItems: 'center', justifyContent: 'center' },
  infoTitle: { color: colors.text, fontSize: 18, fontWeight: '700', marginTop: 16, textAlign: 'center' },
  infoText: { color: colors.textMuted, fontSize: 14, marginTop: 12, textAlign: 'center', lineHeight: 22 },
});
