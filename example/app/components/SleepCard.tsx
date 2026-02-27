import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { SleepDataItem } from '../types';

interface SleepStatItemProps {
  value: string | number;
  label: string;
}

const SleepStatItem: React.FC<SleepStatItemProps> = ({ value, label }) => {
  return (
    <View style={styles.sleepStatItem}>
      <Text style={styles.sleepStatValue}>{value}</Text>
      <Text style={styles.sleepStatLabel}>{label}</Text>
    </View>
  );
};

interface SleepCardProps {
  data: SleepDataItem;
}

const formatDuration = (minutes: number): string => {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${hours}h ${mins}m`;
};

export const SleepCard: React.FC<SleepCardProps> = ({ data }) => {
  return (
    <View style={styles.sleepCard}>
      <View style={styles.sleepHeader}>
        <Text style={styles.sleepTime}>
          {data.sleepTime} → {data.wakeTime}
        </Text>
        <Text style={styles.sleepScore}>评分: {data.sleepQuality}/5</Text>
      </View>
      <View style={styles.sleepStats}>
        <SleepStatItem 
          value={formatDuration(data.deepSleepMinutes)} 
          label="深睡" 
        />
        <SleepStatItem 
          value={formatDuration(data.lightSleepMinutes)} 
          label="浅睡" 
        />
        <SleepStatItem 
          value={formatDuration(data.totalSleepMinutes)} 
          label="总睡眠" 
        />
        <SleepStatItem value={data.wakeUpCount} label="清醒次数" />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  sleepCard: {
    backgroundColor: '#f0f4ff',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  sleepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sleepTime: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  sleepScore: {
    fontSize: 14,
    fontWeight: '600',
    color: '#007AFF',
  },
  sleepStats: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  sleepStatItem: {
    width: '50%',
    padding: 6,
    alignItems: 'center',
  },
  sleepStatValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  sleepStatLabel: {
    fontSize: 11,
    color: '#666',
    marginTop: 2,
  },
});