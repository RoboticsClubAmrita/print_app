import React from 'react';
import { TouchableOpacity, Text, StyleSheet, ActivityIndicator, TouchableOpacityProps } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors } from '../theme/colors';

interface CustomButtonProps extends TouchableOpacityProps {
  title: string;
  loading?: boolean;
  variant?: 'primary' | 'outline' | 'ghost';
}

export function CustomButton({ title, loading, variant = 'primary', style, ...props }: CustomButtonProps) {
  if (variant === 'outline') {
    return (
      <TouchableOpacity style={[styles.outlineBtn, style]} disabled={loading || props.disabled} {...props}>
        {loading ? <ActivityIndicator color={colors.primary} /> : <Text style={styles.outlineText}>{title}</Text>}
      </TouchableOpacity>
    );
  }

  if (variant === 'ghost') {
    return (
      <TouchableOpacity style={[styles.ghostBtn, style]} disabled={loading || props.disabled} {...props}>
          {loading ? <ActivityIndicator color={colors.primary} /> : <Text style={styles.ghostText}>{title}</Text>}
      </TouchableOpacity>
    )
  }

  return (
    <TouchableOpacity
      activeOpacity={0.8}
      disabled={loading || props.disabled}
      style={[styles.container, style]}
      {...props}
    >
      <LinearGradient
        colors={[colors.primary, '#5145A6']}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 0 }}
        style={[styles.gradient, (props.disabled && !loading) && { opacity: 0.5 }]}
      >
        {loading ? (
          <ActivityIndicator color={colors.text} />
        ) : (
          <Text style={styles.text}>{title}</Text>
        )}
      </LinearGradient>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 56,
    borderRadius: 16,
    overflow: 'hidden',
    marginTop: 16,
  },
  gradient: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  text: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  outlineBtn: {
    height: 56,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 16,
  },
  outlineText: {
    color: colors.primary,
    fontSize: 16,
    fontWeight: '700',
  },
  ghostBtn: {
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 8,
  },
  ghostText: {
    color: colors.textMuted,
    fontSize: 15,
    fontWeight: '600',
  }
});
