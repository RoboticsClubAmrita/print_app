import { View, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { useEffect } from 'react';
import * as SecureStore from 'expo-secure-store';
import { colors } from '../theme/colors';

export default function Index() {
  const router = useRouter();

  useEffect(() => {
    async function checkToken() {
      // Small delay just to show a splash/loading
      await new Promise(resolve => setTimeout(resolve, 1000));
      const token = await SecureStore.getItemAsync('userToken');
      if (token) {
        router.replace('/(tabs)');
      } else {
        router.replace('/auth/login');
      }
    }
    checkToken();
  }, []);

  return (
    <View style={{ flex: 1, backgroundColor: colors.background, justifyContent: 'center', alignItems: 'center' }}>
      <ActivityIndicator size="large" color={colors.primary} />
    </View>
  );
}
