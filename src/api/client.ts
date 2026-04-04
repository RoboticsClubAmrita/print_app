import axios from 'axios';
import * as SecureStore from 'expo-secure-store';

// Assuming the backend is running locally on port 5000 or similar
// Replace with correct IP address for local network testing or deployed URL
const BASE_URL = 'http://10.66.209.18:5000/api'; 

export const api = axios.create({
  baseURL: BASE_URL,
  headers: {
    'Content-Type': 'application/json',
    'Bypass-Tunnel-Reminder': 'true' // Bypasses the initial localtunnel warning page
  },
});

api.interceptors.request.use(
  async (config) => {
    const token = await SecureStore.getItemAsync('userToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);
