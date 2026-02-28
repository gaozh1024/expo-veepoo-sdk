import { StyleSheet } from 'react-native';

export const Colors = {
  primary: '#007AFF',
  primaryLight: '#4DA3FF',
  primaryDark: '#0056B3',
  
  success: '#34C759',
  successLight: '#A8E6CF',
  
  warning: '#FF9500',
  warningLight: '#FFE5B4',
  
  danger: '#FF3B30',
  dangerLight: '#FFCDD2',
  
  background: '#F8F9FA',
  surface: '#FFFFFF',
  
  text: {
    primary: '#1A1A2E',
    secondary: '#6B7280',
    tertiary: '#9CA3AF',
    inverse: '#FFFFFF',
  },
  
  border: '#E5E7EB',
  divider: '#F3F4F6',
  
  sleep: {
    deep: '#6366F1',
    light: '#818CF8',
    quality: '#10B981',
  },
  
  health: {
    heart: '#EF4444',
    blood: '#F97316',
    oxygen: '#3B82F6',
    temperature: '#F59E0B',
    stress: '#8B5CF6',
    glucose: '#EC4899',
  },
  
  card: {
    default: '#FFFFFF',
    sleep: '#F0F4FF',
    sport: '#F0FDF4',
    health: '#FEF3C7',
  },
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
};

export const BorderRadius = {
  sm: 6,
  md: 10,
  lg: 14,
  xl: 20,
  full: 9999,
};

export const FontSize = {
  xs: 11,
  sm: 12,
  md: 14,
  lg: 16,
  xl: 18,
  xxl: 24,
  xxxl: 32,
};

export const Shadows = StyleSheet.create({
  sm: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 3,
  },
  lg: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
  },
});

export const createShadow = (opacity: number = 0.08) => ({
  shadowColor: '#000',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: opacity,
  shadowRadius: 4,
  elevation: 3,
});